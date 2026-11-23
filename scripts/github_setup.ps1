#requires -Version 5.1
<#
.SYNOPSIS
    配置 GitHub 仓库协作者与 main 分支保护。

.DESCRIPTION
    通过 GitHub REST API 批量添加协作者，并可开启 main 分支保护。
    Token 从环境变量 GITHUB_TOKEN 读取；未设置时安全提示输入，不写入磁盘。

.PARAMETER Owner
    仓库所有者，默认 cFqr-lang。

.PARAMETER Repo
    仓库名。

.PARAMETER Collaborators
    组员 GitHub 用户名数组。

.PARAMETER Permission
    协作者权限：pull / triage / push / maintain / admin，默认 push。

.PARAMETER ProtectMain
    是否开启 main 分支保护。

.PARAMETER RequireCodeOwnerReviews
    是否要求 Code Owner 审批。需先填好 .github/CODEOWNERS。

.PARAMETER DryRun
    只打印将执行的操作，不调用写接口。

.PARAMETER UseSystemProxy
    使用系统代理。默认绕过系统代理，避免失效代理导致连接失败。

.EXAMPLE
    $env:GITHUB_TOKEN = "<PAT>"
    .\scripts\github_setup.ps1 -Collaborators "alice","bob","carol" -ProtectMain

.EXAMPLE
    .\scripts\github_setup.ps1 -Collaborators "alice","bob","carol" -DryRun
#>
[CmdletBinding()]
param(
    [string]$Owner = "cFqr-lang",
    [string]$Repo = "Data-Visualization-Project-Summer-Olympics-Visual-Analytics-Challenge-",
    [string[]]$Collaborators = @(),
    [ValidateSet("pull", "triage", "push", "maintain", "admin")]
    [string]$Permission = "push",
    [switch]$ProtectMain,
    [switch]$RequireCodeOwnerReviews,
    [switch]$DryRun,
    [switch]$UseSystemProxy
)

$ErrorActionPreference = "Stop"

# GitHub API 需要 TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 本机代理可能未启动，默认绕过；如网络必须走代理，加 -UseSystemProxy
if (-not $UseSystemProxy) {
    [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy
}

function Get-PlainText {
    param([Security.SecureString]$Secure)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Invoke-GitHubApi {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Uri,
        $Body = $null
    )

    $params = @{
        Method      = $Method
        Uri         = $Uri
        Headers     = $script:Headers
        ErrorAction = "Stop"
    }
    if ($null -ne $Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
        $params.ContentType = "application/json"
    }

    try {
        return Invoke-RestMethod @params
    }
    catch {
        $status = "unknown"
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $status = [int]$_.Exception.Response.StatusCode
        }
        $detail = $_.ErrorDetails.Message
        if ([string]::IsNullOrWhiteSpace($detail)) {
            $detail = $_.Exception.Message
        }
        throw "GitHub API 失败（HTTP $status）：$Method $Uri`n$detail"
    }
}

Write-Host "仓库：$Owner/$Repo" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "模式：DRY RUN（不会调用写接口）" -ForegroundColor Yellow
}

if (-not $DryRun) {
    $token = $env:GITHUB_TOKEN
    if ([string]::IsNullOrWhiteSpace($token)) {
        $secure = Read-Host "请输入 GitHub PAT（需要 repo / administration 权限，输入不回显，不保存）" -AsSecureString
        $token = Get-PlainText -Secure $secure
    }
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "未提供 GitHub Token，已中止。"
    }

    $script:Headers = @{
        Authorization          = "Bearer $token"
        Accept                 = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
        "User-Agent"           = "olympics-team-setup"
    }

    $repoInfo = Invoke-GitHubApi -Method "GET" -Uri "https://api.github.com/repos/$Owner/$Repo"
    Write-Host "已连接：$($repoInfo.full_name)（$($repoInfo.visibility)），默认分支 $($repoInfo.default_branch)" -ForegroundColor Green
}

$validCollaborators = @(
    $Collaborators |
        ForEach-Object { $_ -split "[,;]" } |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)

if ($validCollaborators.Count -eq 0) {
    Write-Host "未提供协作者用户名，跳过协作者配置。" -ForegroundColor Yellow
}
else {
    foreach ($user in $validCollaborators) {
        $encodedUser = [uri]::EscapeDataString($user.Trim())
        $uri = "https://api.github.com/repos/$Owner/$Repo/collaborators/$encodedUser"

        if ($DryRun) {
            Write-Host "[DRY RUN] 将添加协作者：$user（$Permission）" -ForegroundColor Yellow
            continue
        }

        Invoke-GitHubApi -Method "PUT" -Uri $uri -Body @{ permission = $Permission } | Out-Null
        Write-Host "已添加/更新协作者：$user（$Permission）" -ForegroundColor Green
        Write-Host "  提示：对方需接受 GitHub 邀请后权限才会生效。" -ForegroundColor DarkGray
    }
}

if ($ProtectMain) {
    $protectionBody = @{
        required_status_checks        = $null
        enforce_admins                = $false
        required_pull_request_reviews = @{
            dismiss_stale_reviews           = $true
            require_code_owner_reviews      = [bool]$RequireCodeOwnerReviews
            required_approving_review_count = 1
        }
        restrictions                  = $null
        required_linear_history       = $true
        allow_force_pushes            = $false
        allow_deletions               = $false
        required_conversation_resolution = $true
    }

    if ($DryRun) {
        Write-Host "[DRY RUN] 将开启 main 分支保护：1 人审批、禁止强推与删除、要求线性历史。" -ForegroundColor Yellow
        if ($RequireCodeOwnerReviews) {
            Write-Host "[DRY RUN] 同时要求 Code Owner 审批。" -ForegroundColor Yellow
        }
    }
    else {
        Invoke-GitHubApi -Method "PUT" -Uri "https://api.github.com/repos/$Owner/$Repo/branches/main/protection" -Body $protectionBody | Out-Null
        Write-Host "已开启 main 分支保护。" -ForegroundColor Green
        if ($RequireCodeOwnerReviews) {
            Write-Host "已要求 Code Owner 审批，请确认 .github/CODEOWNERS 中的用户名有效。" -ForegroundColor Yellow
        }
    }
}
else {
    Write-Host "未启用分支保护；如需启用，加 -ProtectMain。" -ForegroundColor DarkGray
}

Write-Host "完成。" -ForegroundColor Cyan
