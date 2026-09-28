# Copy this file to web-deploy.local.ps1 and fill in your server details.
# The local file is ignored by Git. Use the OpenSSH .pem key (not a .ppk file).
$SshTarget = 'user@server.example.com'
$SshPort = 22
$SshKeyPath = 'D:\path\to\server.pem'
$ProdDirectory = '/data/static-5100/REPLACE_WITH_PROD_DIRECTORY'
$TestDirectory = '/data/static-5200/REPLACE_WITH_TEST_DIRECTORY'
