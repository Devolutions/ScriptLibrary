
<#
    .SYNOPSIS
    Generates a secure random password containing a mix of uppercase, lowercase, numbers, and symbols.

    .DESCRIPTION
    Generates a random password of a specified length. The password includes a mix of
    uppercase letters, lowercase letters, numbers, and special characters. This function uses cryptographic random number
    generation to ensure that the password is generated with a high degree of randomness suitable for secure applications.

    .PARAMETER Length
    Specifies the length of the password to generate. The default length is 12 characters.

    .EXAMPLE
    PS> New-RandomPassword -Length 16
    This example generates a 16-character long random password.

    .EXAMPLE
    PS> New-RandomPassword
    This example generates a random password using the default length of 12 characters.

    .OUTPUTS
    System.Security.SecureString
    The function returns the password as a SecureString to ensure that it is not displayed in plain text or stored in 
    memory as a regular string.
    #>
[CmdletBinding()]
param(
    [int]$Length = 12
)

# Define character sets
$lowercase = 'abcdefghijklmnopqrstuvwxyz'
$uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
$numbers = '0123456789'
$symbols = '!@#$%^&*()_-+=[]{}|;:,.<>?'
    
# Combine all character sets
$charSet = $lowercase + $uppercase + $numbers + $symbols

# Create an array to hold the password characters
$passwordChars = New-Object char[] $Length

# Random number generator
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

# Generate password
for ($i = 0; $i -lt $Length; $i++) {
    $byte = New-Object byte[] 1
    $rng.GetBytes($byte)
    $randomIndex = $byte[0] % $charSet.Length
    $passwordChars[$i] = $charSet[$randomIndex]
}

# Convert the password to a secure string so we don't put plain text passwords on the pipeline.
ConvertTo-SecureString -String (-join $passwordChars) -AsPlainText -Force