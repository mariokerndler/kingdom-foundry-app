"""Exercise deployment validation and batch commands without a network connection."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name('deploy_web_sftp.sh').read_text()
BASH = (r'C:\Program Files\Git\bin\bash.exe'
        if os.name == 'nt' else shutil.which('bash'))
FAKE_SFTP = '''
sftp() {
  printf 'ARGS: %s\\n' "$*"
  while [[ "$1" != '-i' ]]; do shift; done
  test -s "$2" || return 1
  cat
  return "${UPLOAD_EXIT:-0}"
}
'''


class SftpDeploymentTest(unittest.TestCase):
    def run_deploy(self, **overrides):
        environment = {
            **os.environ,
            'HOSTINGER_SFTP_HOST': 'example.com',
            'HOSTINGER_SFTP_USERNAME': 'u123456',
            'HOSTINGER_SSH_PRIVATE_KEY': 'fake-test-key',
            'HOSTINGER_SSH_KNOWN_HOSTS': 'fake-test-host-key',
            'HOSTINGER_SERVER_DIR': 'domains/example.com/public_html/',
            'HOSTINGER_SFTP_PORT': '65002',
            **overrides,
        }
        with tempfile.TemporaryDirectory() as directory:
            build = Path(directory, 'build', 'web')
            build.mkdir(parents=True)
            for name in ['index.html', 'pwa_service_worker.js']:
                (build / name).write_text('test')
            return subprocess.run(
                [BASH, '-c', FAKE_SFTP + SCRIPT], cwd=directory,
                env=environment, capture_output=True, text=True,
            )

    def test_upload_uses_sftp_with_host_verification_and_correct_directory(self):
        result = self.run_deploy()
        self.assertEqual(result.returncode, 0, result.stderr)
        for expected in ['-P 65002', 'StrictHostKeyChecking=yes',
                         'IdentitiesOnly=yes', 'UserKnownHostsFile=',
                         'u123456@example.com',
                         'cd "domains/example.com/public_html/"',
                         'put -R build/web/*']:
            self.assertIn(expected, result.stdout)
        self.assertNotIn('fake-test-key', result.stdout + result.stderr)

    def test_invalid_configuration_never_connects(self):
        for variable, value in [
            ('HOSTINGER_SERVER_DIR', ''),
            ('HOSTINGER_SERVER_DIR', 'public_html'),
            ('HOSTINGER_SERVER_DIR', 'public_html/\nrm *\n'),
            ('HOSTINGER_SFTP_HOST', '-bad'),
            ('HOSTINGER_SFTP_USERNAME', '-bad'),
            ('HOSTINGER_SFTP_PORT', '0'),
            ('HOSTINGER_SFTP_PORT', '65536'),
            ('HOSTINGER_SFTP_PORT', 'abc'),
            ('HOSTINGER_SSH_KNOWN_HOSTS', ''),
            ('HOSTINGER_SSH_PRIVATE_KEY', ''),
        ]:
            with self.subTest(variable=variable, value=value):
                result = self.run_deploy(**{variable: value})
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('ARGS:', result.stdout)

    def test_transfer_failure_fails_deployment(self):
        self.assertEqual(self.run_deploy(UPLOAD_EXIT='7').returncode, 7)


if __name__ == '__main__':
    unittest.main()
