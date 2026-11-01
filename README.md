# ChatGPT Local PC Bridge

**상대방 본인의 ChatGPT 계정 ↔ 상대방 Windows PC의 자체 로컬 MCP 서버**를 연결하기 위한 오픈소스 예제입니다.

외부 업체의 Desktop Commander 패키지, 공개 호스팅 MCP 주소, npm 패키지는 **사용하지 않습니다**. `local-pc-mcp.cjs`는 이 저장소의 자체 코드이며 Node.js 기본 모듈만 사용합니다.

## 구현 상태 — 전체 PC 제어용으로 사용하지 마세요

**현재 공개 배포본은 기존 Local Desktop Commander와 동등한 도구가 아닙니다.** 명령 실행, Windows 프로세스 제어, PC 전체 파일 접근이 없으므로 상대방 PC를 전면 관리하려는 목적의 완성본으로 간주하지 마세요. 설치기에 포함된 자체 로컬 MCP는 아래 4개 제한 기능만 제공합니다.

## 무엇을 할 수 있나

- `pc_info`: 대상 PC 이름·Node 버전·허가된 작업 폴더 확인
- `list_directory`: 작업 폴더 내부의 파일명 조회
- `read_text_file`: 작업 폴더 내부의 텍스트 파일 읽기 (256 KiB 이하)
- `write_text_file`: 작업 폴더 내부의 텍스트 파일 쓰기 (128 KiB 이하, 덮어쓰기 별도 지정)

**기존 Desktop Commander와 기능이 같지 않습니다.** 특히 **임의 CMD/PowerShell 실행**, PC 전체 파일 접근, 프로그램 설치/제어는 지원하지 않습니다. 기본 작업 폴더는 `%USERPROFILE%\ChatGPTLocalFiles`이며 그 밖의 파일은 차단합니다. 심볼릭 링크로 작업 폴더를 벗어나는 것도 막습니다.

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
$p = Join-Path $env:TEMP 'ChatGPTLocalPC-Setup.cmd'; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/limjunseo/chatgpt-local-pc-bridge/main/INSTALL.cmd' -OutFile $p; & $p
```

GitHub에서 다운로드 가능한 코드 자체를 실행하므로 작성자가 바뀌거나 저장소가 변경되면 내용을 재검토해야 합니다. 다운로드한 서버 본문은 설치기 내부에 고정된 SHA-256으로 확인합니다.

## ChatGPT 계정 연결

**ChatGPT 데스크톱 앱**: 지원되는 환경이라면 **Settings → MCP servers → Add server → STDIO**를 선택합니다. Command: `node.exe`, Arguments: `%LOCALAPPDATA%\ChatGPTLocalPCBridge\local-pc-mcp.cjs`의 **확장된 전체 경로**. 환경변수 `LOCAL_PC_ROOT`는 작업 폴더 전체 경로로 지정할 수 있으며 미지정 시 기본값이 사용됩니다. 앱/호스트를 재시작하고 `/mcp`에서 연결 상태를 확인합니다.

**ChatGPT 웹**: 로컬 stdio 서버에 웹에서 직접 접속할 수 없으므로 **OpenAI Secure MCP Tunnel**이 별도로 필요합니다. 사용자의 Platform 조직에서 터널 권한을 부여하고, 사용자 본인의 ChatGPT 워크스페이스에서 터널을 선택해야 합니다. [웹 연결 절차](docs/CONNECT_WEB.md)를 확인하세요.

**중요:** 설치기는 ChatGPT 로그인·터널 생성·OAuth/역할 승인까지 자동 처리하지 않습니다. 네트워크 공개 RDP 포트(3389), 백그라운드 자동 시작을 설정하지 않습니다.

## 검증과 보안

[검증 보고서](docs/TEST_REPORT.md)를 읽으세요. Windows에서 실제 다운로드/해시 검증/파일 설치와 기본 MCP 통신은 시험했지만, **상대방 PC와 상대방 ChatGPT 계정의 실제 연결**은 검증 전입니다.

MCP가 연결된 동안 허용된 폴더의 파일을 AI가 읽거나 수정할 수 있습니다. 권한을 정확히 이해하고 필요한 동안만 활성화하세요. 연결 종료는 ChatGPT의 MCP 비활성화 또는 OpenAI 터널 프로세스 종료로 진행하며, 장기 접근 권한의 철회는 Platform/ChatGPT 설정에서도 별도로 수행해야 합니다.

**공식 참고:** [로컬 MCP 설정](https://learn.chatgpt.com/ko-KR/docs/extend/mcp) · [OpenAI Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels)
