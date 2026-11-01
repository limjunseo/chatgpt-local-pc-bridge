# ChatGPT Local PC Bridge

**상대방 본인의 ChatGPT 계정 ↔ 상대방 Windows PC의 자체 로컬 MCP 서버**를 연결하기 위한 오픈소스 예제입니다.

외부 업체의 Desktop Commander 패키지, 공개 호스팅 MCP 주소, npm 패키지는 **사용하지 않습니다**. `local-pc-mcp.cjs`는 이 저장소의 자체 코드이며 Node.js 기본 모듈만 사용합니다.

## 구현 상태 — 자체 로컬 MCP (v1.1.0)

**현 상태는 기존 Local Desktop Commander와 동일하지 않습니다.** npm/Desktop Commander 제품에 의존하지 않는 자체 구현이며, 로컬 Node.js 기본 모듈로 동작합니다. 현재 MCP 도구는 **11개**입니다.

| 도구 | 기능 |
| --- | --- |
| `pc_info` | PC 정보 확인 |
| `list_directory` | 작업 폴더 목록 |
| `read_text_file` / `read_binary_file` | 텍스트/2 MiB 이하 바이너리 읽기 |
| `write_text_file` / `edit_text_file` | 텍스트 생성·덮어쓰기·정확 문자열 교체 |
| `file_info` | 파일 메타데이터 |
| `create_directory` / `move_file` | 폴더 생성·파일 이동 |
| `search_files` | 파일명/작은 파일 내용 검색 |
| `list_processes` | Windows 프로세스 목록 읽기 |

**지원하지 않는 기능:** 임의 CMD/PowerShell 명령 실행, 프로세스 종료·장기 세션, 프로그램 설치, PC 전체 파일 접근. 파일 접근은 기본적으로 `%USERPROFILE%\ChatGPTLocalFiles` 한 곳으로 제한합니다. 이 범위를 벗어나는 경로와 심볼릭 링크는 거부하도록 구현했습니다. 대상 PC의 실제 기능·환경에 대한 전수 검증을 의미하지 않습니다.

**주의:** 소유자 본인의 ChatGPT 계정에서 이 도구를 사용할 수 있는지(쓰기 권한 포함)는 플랜과 워크스페이스 정책에 따라 다릅니다. 설치 파일만 실행해서 계정이 연결되지는 않습니다.

## Windows에서 두 명령어로 설치 + 연결

상대방 본인의 Platform 터널이 생성돼 있어야 하며, 터널에 **Tunnels Read + Use** 권한이 있는 **런타임 API 키**를 준비하세요. **상대방 PC의 Windows 바탕화면**에 `codex_세팅연결.txt` 파일을 만들고 다음처럼 **실제** 값을 입력합니다(한 줄 또는 두 줄 모두 가능).

```text
TunnelId:tunnel_0123456789abcdef0123456789abcdef,ApiKey:sk-여기에-실제-런타임키
```

**1번 — Windows CMD에서 자체 MCP + 공식 OpenAI tunnel-client 설치**

```cmd
curl.exe -fL "https://raw.githubusercontent.com/limjunseo/chatgpt-local-pc-bridge/2bd05ed264a6c259f688567eb16e700c30e2dfe3/INSTALL.cmd" -o "%TEMP%\ChatGPTLocalPC-Setup.cmd" && call "%TEMP%\ChatGPTLocalPC-Setup.cmd"
```

Node.js 22.12+ 여부 확인(없으면 winget으로 공식 Node.js 설치 제안), 자체 MCP의 커밋·SHA-256 확인, 공식 [openai/tunnel-client](https://github.com/openai/tunnel-client) 최신 안정판 Windows ZIP의 GitHub SHA-256 검증·실행 파일 검사와 동봉된 `cloudflared.exe`·매니페스트 설치까지 수행합니다. 이미 자체 MCP만 설치한 PC에서도 같은 명령으로 터널 클라이언트를 추가할 수 있습니다.

**2번 — 같은 PC/Windows 계정의 CMD에서 TXT 읽기 → init → doctor → run**

```cmd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\ChatGPTLocalPCBridge\SETUP-TUNNEL.ps1" -FromDesktopConfig
```

2번 명령이 실제 파일을 읽고 터널 ID와 런타임 키를 적용하며, **doctor 검사가 정상 통과할 때만 run**으로 진행합니다. CMD 창을 닫으면 터널 연결도 끊기므로 켜두세요. **인증 오류나 계정 권한 문제는 자동 해결되지 않습니다.**

그다음 [ChatGPT 사용자 지정 MCP 서버 추가](https://chatgpt.com/plugins) → **연결: Tunnel** → 해당 터널 선택 → **인증: 인증 없음** → **플러그인 만들기 → 설치** → `pc_info` 도구 호출로 상대방 PC 이름이 나오는지 확인합니다.

**보안:** `codex_세팅연결.txt`는 평문 API 키 파일입니다. 채팅이나 GitHub에 올리지 마세요. 설치가 끝나면 파일을 안전하게 보호하거나 삭제하세요. 삭제하면 나중에 재연결할 때 키를 다시 입력해야 합니다. 설명은 [두 명령어 및 오류 대응 상세 가이드](docs/CONNECT_WEB.md)를 보세요.

설치 내용 확인: [INSTALL.cmd](INSTALL.cmd) · [SETUP-TUNNEL.ps1](SETUP-TUNNEL.ps1). `INSTALL.cmd --dry-run`은 설치하지 않고 Node 및 기존 파일을 점검합니다.

## ChatGPT 계정 연결

**ChatGPT 데스크톱 앱**: 지원되는 환경이라면 **Settings → MCP servers → Add server → STDIO**를 선택합니다. Command: `node.exe`, Arguments: `%LOCALAPPDATA%\ChatGPTLocalPCBridge\local-pc-mcp.cjs`의 **확장된 전체 경로**. 환경변수 `LOCAL_PC_ROOT`는 작업 폴더 전체 경로로 지정할 수 있으며 미지정 시 기본값이 사용됩니다. 앱/호스트를 재시작하고 `/mcp`에서 연결 상태를 확인합니다.

**ChatGPT 웹**: 로컬 stdio 서버에 웹에서 직접 접속할 수 없으므로 **OpenAI Secure MCP Tunnel**이 별도로 필요합니다. **정확한 순서는 MCP 설치 → Platform 터널 생성 및 ChatGPT 워크스페이스 연결 → Windows `tunnel-client` 실행 → ChatGPT 사용자 지정 MCP 서버에서 연결 방식 `Tunnel` 및 인증 `인증 없음` → 플러그인 만들기 → 플러그인 설치 → `pc_info` 실제 호출**입니다. 이 자체 서버는 OAuth를 구현하지 않았으므로 OAuth Client ID/Secret을 입력할 필요가 없습니다. 이미 플러그인 만들기를 눌렀다면 새로 설치하지 말고 [웹 연결 절차의 복구 안내](docs/CONNECT_WEB.md#이미-플러그인으로-만들기를-눌렀다면)를 확인하세요.

**중요:** 설치기는 자체 MCP와 OpenAI 공식 터널 클라이언트 파일까지만 자동 설치합니다. ChatGPT 로그인·Platform 터널 생성·워크스페이스 권한·플러그인 생성/설치는 자동 처리하지 않습니다. 네트워크 공개 RDP 포트(3389), 백그라운드 자동 시작을 설정하지 않습니다.

## 검증과 보안

[검증 보고서](docs/TEST_REPORT.md)를 읽으세요. Windows에서 설치·고정 해시 검증과 11개 도구의 주요 MCP 회귀시험을 수행했지만, **상대방 PC와 상대방 ChatGPT 계정의 실제 연결**은 검증 전입니다.

MCP가 연결된 동안 허용된 폴더의 파일을 AI가 읽거나 수정할 수 있습니다. 권한을 정확히 이해하고 필요한 동안만 활성화하세요. 연결 종료는 ChatGPT의 MCP 비활성화 또는 OpenAI 터널 프로세스 종료로 진행하며, 장기 접근 권한의 철회는 Platform/ChatGPT 설정에서도 별도로 수행해야 합니다.

**공식 참고:** [로컬 MCP 설정](https://learn.chatgpt.com/ko-KR/docs/extend/mcp) · [OpenAI Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels)
