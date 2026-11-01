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


## 검토보고서(2026-11-01) 실제 수정·재검증 반영

근거: 사용자 로컬 폴더 `macos/검토보고서-20261101.md`. 해당 보고서 및 원본 재현 데이터는 변경하지 않았다.

| 보고서 지적 | 변경 | 재검증 |
|---|---|---|
| [P1] LaunchAgent plist 경로 앞 LF | 실행 스크립트·출력·오류 로그 경로를 줄바꿈 없이 쓰고 PlistBuddy로 필드 재검증 | Python plistlib로 생성 plist 파싱, 경로 정확히 비교, 모의 로그인 등록 성공 |
| [P1] TXT 마지막 개행 누락 및 중복·BOM·공백 | 공용 `macos/CONFIG.sh` 파서로 통합 | 한 줄 개행 없음/두 줄/CRLF/UTF-8 BOM/공백 및 중복·잘못된 인코딩 **10/10** |
| [P1] 비 UTF-8·NUL 바이너리 편집으로 파일 손상 | `TextDecoder(fatal:true)`, NUL 차단, 편집 결과 2 MiB 제한 | 유효하지 않은 UTF-8, 바이너리, 과대 확장 모두 수정 없이 거절 |
| [P1 조건부] 기존 하드링크를 통한 범위 탈출 | 안전 경로 확인 시 링크 수 2 이상 파일 거절, 내용 검색에서 제외 | 테스트용 외부 원본 불변 확인 |
| [P2] 최소 macOS 미확인 | `sw_vers`로 버전 확인하고 13 미만이면 중단 | 가짜 macOS 12.7.6은 설치 전 중단, 앱 디렉터리 미생성 |
| [P2] 자동 실행 등록 취소가 수동 run까지 취소 | `CONNECT.sh`에서 자동 실행 취소/실패 후 수동 실행 계속 | 모의 취소 시 init→doctor→run 순서 확인 |
| [P2] TXT 삭제 후 수동 재연결 불가능 | Keychain과 기존 Mac 프로필이 있으면 `AUTOSTART.sh run` 경유 | TXT 삭제 후 재연결 모의 동작 확인 |
| [추가] Bash -n 두 파일 검사 불완전 | CONNECT/AUTOSTART/CONFIG 각각 별도 `bash -n` | 세 스크립트 문법 통과 |
| [추가] 기존 실행 파일 무결성 검사 누락 | 공식 릴리스 내부 파일별 SHA-256 검증 재사용, 불일치 시 안전하게 중단 | 기존 고장 파일은 실행/덮어쓰기 거절 |
| [추가] 큰 파일 검색 누락 미보고 | 제외 건수 및 `limited:true` 표기 | 256 KiB 초과 파일이 검색에서 제외된 경우 확인 가능 |

**결과:** 검토 보고서가 사용한 동일 방식의 Windows/Git Bash 모의 시험(최신 코드로 스냅샷 갱신)에서 연결·키체인·LaunchAgent 분기 **27/27 기대결과 일치**, 신규 MCP 보안 회귀시험 통과, 독립 TXT 파서 **10/10** 통과. 설치 13개 모의 분기에서 arm64·Intel 설치 성공, macOS 12/낡은 Node/손상된 다운로드/누락 아카이브/해시 불일치 기존 번들의 안전 차단 확인. UTF-16 인코딩은 **지원하지 않고 명확히 거절**하도록 변경했다.

검증 위치: 사용자 폴더 `macos/반영검증-20261101/` 및 `macos/tests/review-regressions.cjs`, `macos/tests/config-regressions.sh`.

**여전히 검증하지 않은 부분:** 실제 macOS에서 공식 터널 바이너리 시작, 키체인 보안 팝업과 계정 잠금·macOS LaunchAgent 로그온/절전 복귀, APFS의 링크/파일경로 경쟁 상태, ChatGPT 플러그인 실제 도구 호출과 재로그인 후 연결. 사용자에게 완료로 주장하지 않는다. 자체 MCP의 파일 경로 검사는 운영체제 수준의 강제 샌드박스가 아니다.
