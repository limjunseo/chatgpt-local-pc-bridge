# Mac 전용 최종 설치·연결·자동 실행 가이드

> **Windows와 완전 분리:** 이 문서는 `macos/` 전용이다. 기존 `INSTALL.cmd`, `SETUP-TUNNEL.ps1`, `AUTOSTART-TUNNEL.ps1` 및 Windows MCP는 수정하지 않는다.
>
> **검증 범위:** Mac 전용 서버의 11개 도구 Node 회귀 테스트 및 Bash 구문 검사 통과. macOS 실기기 설치, 공식 실행 파일 실행, 키체인/LaunchAgent 등록, ChatGPT의 실제 `pc_info` 호출은 **아직 실기기 검증 전**.

## 반드시 먼저 이해할 점

- Mac에는 **Mac용 터널 ID를 별도로 생성**하는 것을 권장한다. **Windows와 Mac에서 같은 Tunnel ID로 stdio MCP 클라이언트 2개를 동시에 돌리는 구성은 지원되지 않는다.** 기존 Windows 연결을 중단하거나 덮어쓰지 않도록 Mac에 별도 터널을 만든다.
- https://platform.openai.com/settings/organization/tunnels 에서 Mac 전용 터널을 만들고 해당 ChatGPT 워크스페이스에 연결. 런타임 API 키는 https://platform.openai.com/settings/organization/api-keys 에서 Tunnels Read + Use 권한으로 준비.
- Mac의 Apple Silicon(arm64)과 Intel(x86_64)용 공식 OpenAI ZIP을 각각 SHA-256으로 검증해 설치한다. macOS가 기본 제공하는 `curl`, `shasum`, `unzip` 등 사용.
- Node.js **22.12+** 필요. Homebrew가 있고 Node가 없으면 설치기가 `brew install node`를 제안하며 실행한다. Homebrew도 없다면 공식 Node 설치(https://nodejs.org/en/download) 후 재실행.
- 자체 MCP는 기본 `$HOME/ChatGPTLocalFiles` 안에서만 읽기·쓰기 가능. **전체 Mac 제어나 임의 셸 실행 기능은 없음**.

## 1. Mac 바탕화면 TXT 생성

Mac의 실제 데스크톱에 `codex_세팅연결.txt` 파일 생성. **Mac 전용 Tunnel ID와 그 권한을 가진 런타임 키로 교체:**

```text
TunnelId:tunnel_여기에Mac전용실제ID,ApiKey:여기에실제런타임API키
```

API 키가 평문 파일이므로 GitHub/채팅/공유 폴더에 올리지 말 것. iCloud 데스크톱 동기화도 주의.

## 2. Mac 터미널 명령어 1 — 설치

```bash
curl -fL "https://raw.githubusercontent.com/limjunseo/chatgpt-local-pc-bridge/89ef35eabd89073d886d77aac49002ac9fa8a56e/macos/INSTALL.sh" -o "$HOME/Downloads/ChatGPTLocalMac-INSTALL.sh" && bash "$HOME/Downloads/ChatGPTLocalMac-INSTALL.sh"
```

PC 소유자 설치 동의 `y`를 입력. 설치 경로:

- `$HOME/Library/Application Support/ChatGPTLocalPCBridgeMac/local-mac-mcp.cjs`
- `$HOME/Library/Application Support/ChatGPTLocalPCBridgeMac/bin/tunnel-client`
- `$HOME/Library/Application Support/ChatGPTLocalPCBridgeMac/bin/cloudflared`
- `$HOME/Library/Application Support/ChatGPTLocalPCBridgeMac/CONNECT.sh`
- `$HOME/Library/Application Support/ChatGPTLocalPCBridgeMac/AUTOSTART.sh`

**Mac 설치기는 Windows의 파일·서비스·터널 설정을 건드리지 않는다.** 첫 명령만으로 자동 실행을 등록하지 않는다.

## 3. Mac 터미널 명령어 2 — 터널 연결·검사·실행

```bash
bash "$HOME/Library/Application Support/ChatGPTLocalPCBridgeMac/CONNECT.sh"
```

자동 작업: 바탕화면 TXT 읽기 → Mac 전용 stdio MCP 프로필 `chatgpt-local-mac` 초기화 → `doctor --explain` → `run`. **doctor 오류가 있다면 연결이 시작되지 않는다.**

doctor가 성공하면 **로그인 자동 실행 등록 여부**를 묻는다. 원하는 경우 `y`. 이후 추가 동의 질문에서 평문 TXT를 삭제하려면 `y`. 실제 키는 **Mac 로그인 키체인(Keychain)**에 저장되며, 명령행 인자나 로그에 출력하지 않도록 구성했다. 키체인의 접근 권한 승인 팝업이 나올 수 있다.

**현재 터널을 수동 실행하는 터미널은 닫지 말 것.** 해당 Mac 터널을 다른 Mac 또는 Windows에서 동일 ID로 중복 실행하지 말 것.

## 4. ChatGPT 플러그인 추가

1. 터널이 실행 중인 상태에서 https://chatgpt.com/plugins 열기.
2. 사용자 지정 MCP 서버 추가 → 이름: `ChatGPT Local Mac Bridge`.
3. 연결: **Tunnel** → **Mac 전용 터널** 선택. 인증: **인증 없음**(이 자체 MCP는 OAuth 미구현).
4. 위험 안내 확인 후 **플러그인으로 만들기 → 설치**.
5. 새 채팅에서 `ChatGPT Local Mac Bridge의 pc_info 도구로 연결된 Mac 이름과 작업 폴더를 알려줘`로 실제 호출 검증.

## 5. Mac 로그인 시 자동 실행 테스트

자동 시작을 `y`로 등록한 경우 다음 macOS 계정 로그인 때 사용자 전용 LaunchAgent가 터널 실행을 시도한다. **백그라운드 LaunchAgent이므로 Windows처럼 보이는 터미널 창은 자동으로 열리지 않는다.**

- 로그 경로: `$HOME/Library/Application Support/ChatGPTLocalPCBridgeMac/logs/`
- 현재 Mac 로그인 계정에서 `bash "$HOME/Library/Application Support/ChatGPTLocalPCBridgeMac/AUTOSTART.sh" status`로 등록 상태 확인.
- 실제 재로그인 후 ChatGPT에서 `pc_info`가 성공해야 자동 재연결 검증 완료.
- 키체인 접근 확인 팝업/로그인 키체인 잠금 또는 네트워크 오류가 있을 수 있다. `status`만으로 실제 연결 성공을 뜻하지 않는다.

**자동 시작 해제:**

```bash
bash "$HOME/Library/Application Support/ChatGPTLocalPCBridgeMac/AUTOSTART.sh" disable
```

소유자 `y` 동의 뒤 로그인 LaunchAgent와 이 프로젝트 키체인 항목을 삭제한다. **이미 별도의 터미널에서 실행 중인 수동 터널은 직접 종료해야 한다.**

## 6. Mac 전용 파일 및 제한

- GitHub: https://github.com/limjunseo/chatgpt-local-pc-bridge/tree/main/macos
- 공식 Secure MCP Tunnel: https://developers.openai.com/api/docs/guides/secure-mcp-tunnels
- macOS 공식 실행 파일: https://github.com/openai/tunnel-client/releases/latest
- macOS 고유 구현: `macos/local-mac-mcp.cjs` (프로세스 조회 시 읽기 전용 `/bin/ps`, 파일 작업 범위 제한).
- Keychain 비밀번호 쓰기는 `/usr/bin/security -i`의 표준 입력으로 처리해 **OS 프로세스 인자에 비밀 값을 넣지 않도록** 설계. 실제 Mac 키체인의 액세스 정책/사용자 승인 과정은 실기기에서 반드시 확인해야 한다.
- Mac 자동 실행은 `~/Library/LaunchAgents/com.limjunseo.chatgpt-local-mac-bridge.tunnel.plist` 하나만 생성하며, `KeepAlive=false`: 실패 시 계속 자동 재시작하지 않는다. **사용자가 명시적으로 동의한 경우에만** 등록된다.
- Mac OS 버전, Apple Silicon/Intel, 키체인 접근 권한, LaunchAgent GUI 세션에 따라 결과가 달라질 수 있다. 완전한 성공 판정은 실제 Mac 설치·doctor·run·ChatGPT `pc_info`·재로그인 재테스트까지다.

## 7. Windows 원본과 차이

| 항목 | Windows 원본 | macOS 별도 구현 |
|---|---|---|
| 설치기 | `INSTALL.cmd` | `macos/INSTALL.sh` |
| 로컬 MCP | `local-pc-mcp.cjs` | `macos/local-mac-mcp.cjs` |
| 터널 연결 | `SETUP-TUNNEL.ps1` | `macos/CONNECT.sh` |
| 자동 시작 | Windows 시작프로그램 | macOS 사용자 LaunchAgent |
| 키 저장 | Windows DPAPI | macOS Keychain |
| 프로필 | `chatgpt-local-pc` | `chatgpt-local-mac` |
| 터널 ID | Windows용 고유 ID | **Mac용 별도 고유 ID** |
