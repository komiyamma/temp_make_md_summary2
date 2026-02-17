# --- 設定 ---
$API_KEY = $env:JULES_API_KEY
$HEADERS = @{
    "X-Goog-Api-Key" = $API_KEY
    "Content-Type"   = "application/json"
}
$BASE_URL = "https://jules.googleapis.com/v1alpha"

# 1. セッションの開始
Write-Host "🚀 Jules セッションを開始します..." -ForegroundColor Cyan
$body = @{
    prompt = "このリポジトリの gemini_command.md の内容を実行してください。質問は一切不要。最後まで実行せよ。"
    sourceContext = @{
        source = "sources/github/komiyamma/temp_make_md_summary2"
        githubRepoContext = @{ startingBranch = "main" }
    }
    requirePlanApproval = $false
    automationMode = "AUTO_CREATE_PR"
    title = ".md を要約して、→.memoファイルを作成せよ。"
} | ConvertTo-Json -Depth 10

# Invoke-RestMethod によりレスポンスは自動的にオブジェクト化される
$session = Invoke-RestMethod -Uri "$BASE_URL/sessions" -Method Post -Headers $HEADERS -Body $body
$sessionName = $session.name # "sessions/xxxxxxxx"

Write-Host "✅ セッション作成完了: $sessionName"

# 2. 3分おきに完了チェック (state が COMPLETED になるのを待機)
Write-Host "⏳ 作業完了を待機中（3分間隔）..." -ForegroundColor Yellow
while ($true) {
    $current = Invoke-RestMethod -Uri "$BASE_URL/$sessionName" -Headers $HEADERS
    
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - 現在のステータス: $($current.state)"
    
    if ($current.state -eq "COMPLETED") {
        Write-Host "🎉 Jules の作業が正常に完了しました。" -ForegroundColor Green
        break
    } elseif ($current.state -eq "FAILED" -or $current.state -eq "CANCELLED") {
        Write-Error "❌ Jules の作業が失敗またはキャンセルされました。 (State: $($current.state))"
        exit
    }
    
    Start-Sleep -Seconds 180
}

# 3. Publish (PR作成) を要請
#Write-Host "📤 Publish (Pull Request 作成) を要請します..." -ForegroundColor Cyan
# POST /v1alpha/{name}:publish を実行
# $publishResponse = Invoke-RestMethod -Uri "$BASE_URL/$sessionName:publish" -Method Post -Headers $HEADERS

# 4. GitHub CLI (gh) を使った操作
# 最新のセッション情報を取得して PR URL を特定
$sessionInfo = Invoke-RestMethod -Uri "$BASE_URL/$sessionName" -Headers $HEADERS
$prUrl = $sessionInfo.output.pullRequest.url

if (-not $prUrl) {
    Write-Warning "PR URL が取得できませんでした。gh コマンドで最新の PR を探します。"
    $prUrl = gh pr list --repo "komiyamma/temp_make_md_summary2" --limit 1 --json url --jq ".[0].url"
}

Write-Host "🛠️ PR 承認とマージを実行します: $prUrl" -ForegroundColor Cyan

# あなた (komiyamma) を Assignee に追加
gh pr edit $prUrl --add-assignee "komiyamma"

# 承認
gh pr review $prUrl --approve --body "Approved by komiyamma automation script."

# マージ (main に対してマージし、ブランチを削除)
gh pr merge $prUrl --merge --delete-branch

# 5. ローカルへの同期
Write-Host "📥 ローカルの main ブランチを更新します..." -ForegroundColor Green
git checkout main
git pull origin main

Write-Host "✨ すべての工程が完了しました！" -ForegroundColor Green

