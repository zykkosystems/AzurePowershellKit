$name = 'Data-Hub'
$applicationName = 'AutomationAccount-DH'

# 1.Sign in to your account.
Write-Output "BEGIN STEP 1"
$account = Login-AzureRmAccount
if ($account -eq $null) {
    throw "You must sign in to continue running this script."
}

# 2.Create the Certificate
Write-Output "BEGIN STEP 2"
<#
    NOTE: for the certificate to be found by the Login-AzureRmAccount cmdlet, it must be in CurrentUser\My
#>
$thumbprint = (New-SelfSignedCertificate -DnsName "$name" -CertStoreLocation Cert:\CurrentUser\My -KeySpec KeyExchange).Thumbprint
$cert = (Get-ChildItem -Path cert:\CurrentUser\My\$thumbprint)
mkdir "C:\${name}"
Export-Certificate -Cert $cert -FilePath "C:\${name}\${name}.cer" -Type CERT
$password = Read-Host -Prompt "Enter a password for the new .pfx certificate:" -AsSecureString
if ($password -eq $null) {
    throw "You must enter a password so the .pfx can be created"
}
Export-PfxCertificate -Cert $cert -FilePath "C:\${name}\${name}.pfx" -Password $password 

# 3. create an X509Certificate object from your certificate and retrieve the key value. 
Write-Output "BEGIN STEP 3"
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate("C:\${name}\${name}.pfx", $password)
$keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())

# 4. Create an application in the directory with key values.
Write-Output "BEGIN STEP 4"
$azureAdApplication = New-AzureRmADApplication -DisplayName "${applicationName}" -HomePage "https://${applicationName}" -IdentifierUris "https://${applicationName}" -KeyValue $keyValue -KeyType AsymmetricX509Cert       

# 5.Create a service principal 
Write-Output "BEGIN STEP 5"
$servicePrincipal= New-AzureRmADServicePrincipal -ApplicationId $azureAdApplication.ApplicationId

# 6. Grant the Service Principal role
Write-Output "BEGIN STEP 6"
New-AzureRmRoleAssignment -RoleDefinitionName Owner -ServicePrincipalName $azureAdApplication.ApplicationId 

<#
# OPTIONAL
# 7.Log in to Azure using ServicePrincipal
Write-Output "BEGIN STEP 7"
$tenantId = $account.Context.Subscription.TenantId
Login-AzureRmAccount -ServicePrincipal -TenantId $tenantId -CertificateThumbprint $thumbprint -ApplicationId $azureAdApplication.ApplicationId
#>

Write-Output "Done."