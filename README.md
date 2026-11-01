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

## 설치 — 상대방 Windows PC

1. 먼저 설치 파일의 출처와 내용을 확인하세요: [INSTALL.cmd](INSTALL.cmd).
2. 이 파일을 내려받아 **상대방 PC에서 직접** 실행하세요. 본인의 설치 동의, 필요 시 Windows UAC 승인이 필요합니다.
3. 스크립트가 Node.js **22.12 이상**을 확인하고, 없으면 공식 Node.js LTS를 `winget`으로 설치/업그레이드하도록 제안합니다.
4. 설치기는 같은 GitHub 저장소의 [local-pc-mcp.cjs](local-pc-mcp.cjs)를 HTTPS로 내려받고 **SHA-256 값을 확인한 후에만** 설치합니다.
5. 설치 성공 후 표시되는 로컬 MCP 실행 경로를 이용해 상대방 **본인의 ChatGPT 계정**에 연결합니다.

Windows CMD에서 환경 검사만 하려면 `INSTALL.cmd --dry-run`을 실행하세요. 설치·다운로드·계정 연결 없이 사전 점검만 진행합니다.

### 설치 파일 전송이 안 되면

상대방 PC의 **PowerShell**에서 다음 명령어를 실행할 수 있습니다 (실행 전 저장소의 설치 파일 내용을 확인하세요).

```powershell
$p = Join-Path $env:TEMP 'ChatGPTLocalPC-Setup.cmd'; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/limjunseo/chatgpt-local-pc-bridge/7a65b37f7a9d0c9698284a5fb4104eb90689923a/INSTALL.cmd' -OutFile $p; & $p
```

GitHub에서 다운로드한 CMD를 실행하므로 반드시 내용을 확인해야 합니다. MCP 서버는 설치기에서 **특정 GitHub 커밋과 SHA-256**으로 고정해, `main` 브랜치의 캐시나 변경으로 서버 버전이 어긋나지 않게 했습니다. 향후 버전 업데이트에는 설치기의 커밋 ID와 해시를 함께 변경해야 합니다.

## ChatGPT 계정 연결

**ChatGPT 데스크톱 앱**: 지원되는 환경이라면 **Settings → MCP servers → Add server → STDIO**를 선택합니다. Command: `node.exe`, Arguments: `%LOCALAPPDATA%\ChatGPTLocalPCBridge\local-pc-mcp.cjs`의 **확장된 전체 경로**. 환경변수 `LOCAL_PC_ROOT`는 작업 폴더 전체 경로로 지정할 수 있으며 미지정 시 기본값이 사용됩니다. 앱/호스트를 재시작하고 `/mcp`에서 연결 상태를 확인합니다.

**ChatGPT 웹**: 로컬 stdio 서버에 웹에서 직접 접속할 수 없으므로 **OpenAI Secure MCP Tunnel**이 별도로 필요합니다. 사용자의 Platform 조직에서 터널 권한을 부여하고, 사용자 본인의 ChatGPT 워크스페이스에서 터널을 선택해야 합니다. [웹 연결 절차](docs/CONNECT_WEB.md)를 확인하세요.

**중요:** 설치기는 ChatGPT 로그인·터널 생성·OAuth/역할 승인까지 자동 처리하지 않습니다. 네트워크 공개 RDP 포트(3389), 백그라운드 자동 시작을 설정하지 않습니다.

## 검증과 보안

[검증 보고서](docs/TEST_REPORT.md)를 읽으세요. Windows에서 설치·고정 해시 검증과 11개 도구의 주요 MCP 회귀시험을 수행했지만, **상대방 PC와 상대방 ChatGPT 계정의 실제 연결**은 검증 전입니다.

MCP가 연결된 동안 허용된 폴더의 파일을 AI가 읽거나 수정할 수 있습니다. 권한을 정확히 이해하고 필요한 동안만 활성화하세요. 연결 종료는 ChatGPT의 MCP 비활성화 또는 OpenAI 터널 프로세스 종료로 진행하며, 장기 접근 권한의 철회는 Platform/ChatGPT 설정에서도 별도로 수행해야 합니다.

**공식 참고:** [로컬 MCP 설정](https://learn.chatgpt.com/ko-KR/docs/extend/mcp) · [OpenAI Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels)
