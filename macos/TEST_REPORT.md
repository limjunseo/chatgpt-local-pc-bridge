# macOS 독립 구현 검증 기록 (2026-11-01)

## 확인된 사항

- Windows 파일 `INSTALL.cmd`, `SETUP-TUNNEL.ps1`, `AUTOSTART-TUNNEL.ps1`, `local-pc-mcp.cjs`은 이 macOS 구현 작업에서 변경하지 않았다.
- GitHub에 Mac 전용 `macos/INSTALL.sh`, `macos/CONNECT.sh`, `macos/AUTOSTART.sh`, `macos/local-mac-mcp.cjs`, `macos/README.md`, `macos/tests/smoke.cjs`을 추가했다.
- Mac 전용 세 셸 스크립트는 Git Bash의 `bash -n` 문법 검사 통과(세 파일 모두 종료 코드 0).
- Mac MCP의 `node --check` 통과.
- 별도의 회귀 테스트 `node macos/tests/smoke.cjs` 통과: MCP initialize/tools/list/pc_info, 파일 읽기·쓰기·수정·이동, 검색, 경로 이탈 차단, 임의 명령 거부, 바이너리 읽기, ping 등을 검증. **테스트 호스트는 Windows이므로 Mac 고유 `/bin/ps` 실행 검증은 포함되지 않음.**
- 공식 오픈소스 `openai/tunnel-client` 릴리스 `v0.0.19`에서 Apple Silicon(arm64)와 Intel(amd64) ZIP 둘 다 실제 다운로드 및 공식 GitHub 릴리스 SHA-256 대조, 동봉된 `tunnel-client`·`cloudflared`·`cloudflared-manifest.json` 존재 확인.
  - arm64 ZIP SHA-256: `2243d024b77af8ee4b4ab7a1447949e5fc8d82bcd2d51b178927f2da9e47ecfd`.
  - amd64 ZIP SHA-256: `dff97674c77cac59e6ab3d901e6cff50fb17a5784c01d8959d1f4adb3afdf4bf`.
- 설치기는 공개 저장소의 Mac MCP/연결/자동 시작 코드도 각각 고정 커밋과 SHA-256을 검증해 내려받는다.
- Keychain 저장 시 API 키를 `security -i` 표준 입력으로 전달하도록 설계하여 OS 프로세스 인자로 노출하지 않는다. 자동 로그인 시작은 사용자 확인 후에만 LaunchAgent를 작성한다.

## 아직 검증되지 않은 사항

- **실제 macOS 컴퓨터에서 INSTALL.sh 설치 실행, Mac 바이너리 실행, `tunnel-client init/doctor/run` 성공.**
- **실제 Keychain `security -i` 입력, 암호 저장·복호화, 보안 접근 승인/권한 정책.**
- **실제 macOS LaunchAgent의 로그인 시 실행·키체인 잠금/해제 동작 및 로그.**
- **ChatGPT 사용자 지정 MCP 플러그인에서 Mac의 `pc_info` 호출과 재로그인 후 재호출.**
- Mac TCC/권한 정책, iCloud Desktop 동기화와 Mac의 Node/Brew 설치 권한 문제.

이 사항들은 Mac 실기기 테스트 전에는 완료했다고 말할 수 없다. 설치기 사용자는 최신 권한과 macOS 버전에 맞춰 직접 확인해야 한다.

## 별도 터널 요구

공식 tunnel-client의 stdio 라우팅은 **같은 Tunnel ID로 여러 클라이언트를 동시에 실행하는 방식이 지원되지 않는다.** 따라서 기존 Windows PC의 터널은 그대로 두고, Mac에는 **새로운 전용 Tunnel ID**를 만들도록 가이드한다.

## 비밀·권한 경계

Mac에서만 `~/Library/Application Support/ChatGPTLocalPCBridgeMac`, `~/Library/LaunchAgents/com.limjunseo.chatgpt-local-mac-bridge.tunnel.plist`, macOS Keychain 서비스 `ChatGPTLocalMacBridgeRuntimeKey`를 사용한다. 현재 사용자 명시적 승인 없이 자동 시작은 활성화하지 않으며, 다른 PC(Windows 포함)의 설치/키/터널 ID를 수정하지 않는다.
