# ChatGPT 웹에 자체 Local PC Bridge 연결하기 (2026-11-01)

이 가이드는 **상대방 본인의 Windows PC, 본인의 ChatGPT 계정 및 연결 권한**을 전제로 합니다. 로컬 PC Bridge는 외부 Desktop Commander MCP 제품을 설치하지 않습니다. 단, 현재 버전(v1.1.0)은 지정 폴더 파일 관리·검색 및 프로세스 **조회** 등 11개 기능만 제공하며, PowerShell/CMD 실행, 프로그램 설치, 프로세스 종료, PC 전체 파일 접근은 **지원하지 않습니다**.

## 정확한 설치·연결 순서

**PC에 자체 MCP 설치 → Platform 터널 만들기 → 터널과 ChatGPT 워크스페이스 연결·권한 설정 → 상대방 PC에서 터널 클라이언트 설치/실행 → ChatGPT에서 사용자 지정 MCP 플러그인 생성(인증 없음) → 플러그인 설치 → 실제 도구 호출 테스트**.

이미 **[플러그인으로 만들기]**를 눌렀어도 PC나 MCP를 다시 설치할 필요는 없습니다. 아래의 **이미 버튼을 눌렀다면**을 먼저 확인하세요.

### 1. 자체 MCP 설치 상태 확인

상대방 Windows PC의 기존 설치 로그에서 아래가 나왔다면 설치 성공입니다.

- Node 실행 파일: `node.exe`
- MCP 서버 파일: `%LOCALAPPDATA%\ChatGPTLocalPCBridge\local-pc-mcp.cjs`
- 로컬 작업 폴더: `%USERPROFILE%\ChatGPTLocalFiles`
- [SUCCESS] 설치 성공 / [NOT CONNECTED] 아직 ChatGPT와 미연결

설치한 MCP 파일에 대한 정보는 이 명령으로 확인합니다.

```powershell
$server = Join-Path $env:LOCALAPPDATA 'ChatGPTLocalPCBridge\local-pc-mcp.cjs'
$workspace = Join-Path $env:USERPROFILE 'ChatGPTLocalFiles'
Test-Path $server
Test-Path $workspace
node.exe --check $server
```

모두 정상이라면 설치기를 다시 실행할 필요 없습니다. 기존 설치 창은 닫아도 됩니다.

### 2. Platform에서 상대방 계정/조직의 Secure MCP Tunnel 생성

- https://platform.openai.com/settings/organization/tunnels 로 이동
- **상대방에게 권한이 있는 Platform 조직** 선택 후 터널 생성
- 생성된 `tunnel_id`를 기록. **런타임 API 키와는 다릅니다.**
- 터널에 **실제로 이용할 ChatGPT 워크스페이스**를 연결(association). Platform 조직에만 연결하면 ChatGPT에서 목록에 안 보일 수 있음
- 터널 생성자는 **Tunnels Read + Manage**, 사용자와 런타임 키 주체는 **Tunnels Read + Use** 권한 필요

조직 정책/권한 때문에 생성 버튼이 안 보이면 조직 소유자 또는 관리자에게 해당 권한을 요청합니다.

### 3. 런타임 API 키 발급 (OAuth 아님)

- https://platform.openai.com/settings/organization/api-keys 에서 대상 조직의 **런타임용 API 키** 준비
- 가능한 경우 터널 실행에 필요한 **Tunnels Read + Use**만 부여
- **런타임 키는 `tunnel-client`가 OpenAI와 통신하기 위한 자격증명이며, ChatGPT 사용자 지정 MCP 화면의 OAuth 설정이 아닙니다.**
- 키는 채팅창, 화면 공유, GitHub, 일반 텍스트 가이드, 캡처 사진에 붙여넣지 않습니다

### 4. 상대방 Windows PC에서 OpenAI 공식 `tunnel-client` 설치·설정

공식 릴리스: https://github.com/openai/tunnel-client/releases/latest

Windows용 실행 파일을 받아 상대방 PC의 본인이 선택한 폴더(예: `C:\Tools\OpenAITunnel`)에 두고 **그 폴더에서 PowerShell을 엽니다**. 현재 클라이언트 버전 사용법부터 확인하세요.

```powershell
.\tunnel-client.exe help quickstart
.\tunnel-client.exe init --help
```

아래 예시의 `YOUR_TUNNEL_ID`만 **2번에서 발급받은 실제 ID**로 바꾸세요.

```powershell
$env:LOCAL_PC_ROOT = Join-Path $env:USERPROFILE 'ChatGPTLocalFiles'
$mcpFile = Join-Path $env:LOCALAPPDATA 'ChatGPTLocalPCBridge\local-pc-mcp.cjs'
$mcpCommand = 'node.exe "' + $mcpFile + '"'
.\tunnel-client.exe init --sample sample_mcp_stdio_local --profile chatgpt-local-pc --tunnel-id YOUR_TUNNEL_ID --mcp-command $mcpCommand
```

실행 직전 현재 터미널 세션에서 키를 **화면에 표시하지 않는 방식으로** 입력합니다(명령 인수에 키를 직접 쓰지 말 것).

```powershell
$secureKey = Read-Host 'Tunnel runtime API key (입력 내용은 표시되지 않음)' -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
try { $env:CONTROL_PLANE_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
Remove-Variable secureKey,ptr
.\tunnel-client.exe doctor --profile chatgpt-local-pc --explain
.\tunnel-client.exe run --profile chatgpt-local-pc
```

`run`이 정상 실행 중인 터미널을 **닫으면 연결이 끊어집니다**. 운영 중에는 지속 실행 상태가 필요합니다. 우선 `doctor` 성공, `run` 연결 및 폴링 상태를 확인한 후 다음 단계로 진행합니다. 클라이언트 버전별 명령이 달라지면 `help quickstart`의 실제 출력이 우선입니다.

### 5. ChatGPT 웹에서 ‘사용자 지정 MCP 서버’ 생성

- https://chatgpt.com/plugins → `+` → **사용자 지정 MCP 서버 추가**
- 이름: `ChatGPT Local PC Bridge`
- 설명(선택): `내 Windows PC의 허용된 파일을 관리하는 자체 MCP`
- **연결(Connection): `Tunnel`** 선택 후 2번의 터널 지정. URL 모드가 아니므로 로컬 파일 경로나 GitHub 주소를 서버 URL에 넣지 않습니다.
- **인증(Authentication): `인증 없음`** 선택
- 위험 안내를 읽고 `이해했으며 계속 진행하겠습니다` 선택
- **플러그인으로 만들기** 클릭
- 생성한 플러그인을 개인/워크스페이스 목록에서 찾아 **설치(Install)**. 도구 11개가 발견됐는지 확인

#### OAuth가 안 보이거나 찾지 못했다면

이 자체 MCP에는 OAuth 서버를 구현하지 않았으므로 **OAuth 설정 화면이나 Client ID / Client Secret을 찾을 필요가 없습니다**. 공식 UI에는 `OAuth`, `인증 없음`, `OAuth 또는 인증 없음`이 있습니다. 이 프로젝트에는 **`인증 없음`**을 선택하면 됩니다.

`인증 없음`은 MCP 애플리케이션 자체가 OAuth로 로그인하지 않는다는 의미일 뿐, OpenAI 터널 런타임 API 키나 Platform/ChatGPT 접근 권한을 생략한다는 의미가 **아닙니다**.

### 이미 ‘플러그인으로 만들기’를 눌렀다면

1. **생성 성공했다면:** https://chatgpt.com/plugins 에서 만들어진 `ChatGPT Local PC Bridge`를 찾고 연결이 `Tunnel`로 설정되었는지 확인합니다. 올바른 `tunnel_id`가 지정됐다면 2~4단계를 마치고 플러그인 상세에서 **새로 고침(Refresh)** / 도구 동기화를 실행한 뒤 **설치(Install)**합니다.
2. **URL 방식으로 만들었거나 잘못된 터널을 선택했다면:** 플러그인 상세의 연결 편집 가능 여부를 확인하고, 편집할 수 없다면 **올바른 터널 연결로 새 사용자 지정 MCP 플러그인을 만듭니다**. 기존 항목은 확인한 뒤 필요할 때만 정리합니다.
3. **생성 실패 또는 연결 테스트 오류가 떴다면:** 아직 만들어진 것으로 간주하지 않습니다. 2~4단계(터널 ID, ChatGPT 워크스페이스 association, Tunnels Read + Use, 클라이언트 doctor/run)를 확인하고 다시 시도합니다.
4. **터널 목록이 비어 있거나 비활성이라면:** Platform 조직만 연결된 건 아닌지, ChatGPT 워크스페이스 association 및 사용자 Use 권한이 있는지 확인합니다.

### 6. 연결 성공 검증

ChatGPT 새 대화에서 설치된 플러그인을 `@`로 선택하고 다음처럼 요청합니다.

> `ChatGPT Local PC Bridge` 플러그인의 `pc_info` 도구를 호출해서 연결된 PC의 hostname과 workspace를 보여줘.

실제 상대방 PC의 hostname과 설치 작업 폴더가 나타나면 **MCP 도구 호출까지 성공**한 것입니다. 다음으로 허용된 `ChatGPTLocalFiles` 폴더에 테스트 텍스트 파일을 만들어 쓰기 기능을 점검할 수 있습니다. 테스트가 끝나면 삭제 여부를 확인하세요.

**이것이 확인되기 전에는 ‘최종 연결 완료’라고 말하면 안 됩니다.** 설치/플러그인 생성 버튼만으로는 완성되지 않습니다.

### 흔한 오류

| 증상 | 먼저 확인할 사항 |
| --- | --- |
| OAuth 설정을 못 찾음 | 이 MCP는 OAuth를 쓰지 않으므로 **인증 없음** 사용 |
| 터널이 목록에 안 보임 | 조직 + 대상 ChatGPT 워크스페이스 연결, Tunnels Use |
| 플러그인 생성 시 연결 실패 | 실제 `tunnel-client run` 실행/대기 중인지, `doctor` 출력 |
| 키 인증 실패 | 프로젝트 키가 아니라 적절한 런타임 키인지, Tunnels Read + Use 권한 |
| MCP 파일을 찾을 수 없음 | 설치 로그에 출력된 서버 파일 경로와 실행 Windows 사용자 확인 |
| 플러그인 생성됐지만 채팅에서 안 보임 | 플러그인 **설치** 여부, 도구 새로 고침, 워크스페이스 정책 확인 |
| pc_info는 되는데 PowerShell 실행이 안 됨 | **현재 자체 MCP는 CMD/PowerShell 실행 도구가 없음** |

### 연결 종료/비활성화

PowerShell에서 실행 중인 `tunnel-client run`을 중지하면 접속이 끊어집니다. 장기 권한 철회는 플러그인 연결 해제, 터널 액세스 제거, 런타임 키 폐기/교체를 별도로 처리합니다. 이 설치 스크립트는 자동 시작/백그라운드 서비스를 만들지 않습니다.

## 공식 근거

- https://developers.openai.com/api/docs/guides/secure-mcp-tunnels
- https://developers.openai.com/api/docs/guides/custom-mcp-server
- https://github.com/openai/tunnel-client/blob/master/docs/onboarding.md

> 참고: 여기서는 로컬 설치·MCP 테스트까지만 확인했습니다. **상대방 계정에서 터널과 플러그인 호출이 끝까지 성공했는지는 확인되지 않았습니다.**
