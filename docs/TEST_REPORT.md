# ChatGPT Local PC Bridge 검증 보고서 — 2026-11-01

## 설계

- 이름: **ChatGPT Local PC Bridge**
- 외부 Desktop Commander 패키지 설치: **없음**
- npm 의존성: **0**
- Node.js 표준 모듈만 사용: fs/path/os/readline
- 공개 호스팅 MCP URL 사용: **없음**
- 연결 방식: ChatGPT Desktop STDIO 또는 별도 OpenAI Secure MCP Tunnel
- 기본 파일 범위: `%USERPROFILE%\ChatGPTLocalFiles`만 허용
- 원격 임의 명령 실행: **지원하지 않음**

## 이번에 실제 확인한 것

- Windows 11, Node.js **24.13.1** 환경의 로컬 소스 `node.exe --check`: 통과.
- 로컬 stdio MCP JSON-RPC `initialize`, `tools/list`, `tools/call pc_info`, `tools/call read_text_file`: 정상 응답.
- 상대 경로로 작업 폴더 밖에 있는 파일 읽기 요청: `isError=true` 및 거부.
- GitHub 공개 소스 HTTP 다운로드: 성공.
- 설치 파일에 명시된 서버 SHA-256: `5A13141F7615CC7C49659BC2BE70B149DFD7735EFF218ED9BAF661A676A313F7`.
- `INSTALL.cmd --help`: 종료 0.
- `INSTALL.cmd --dry-run`: 종료 0, 사전 점검만 수행.
- 오타/추가 옵션: 종료 11.
- 별도 TEMP 사용자 경로로 격리한 **실제 설치 테스트**: 동의 입력 → GitHub 다운로드 → SHA-256 확인 → `node --check` → 설치 완료, 종료 0.
- 실제 설치된 파일 SHA-256: 기대값과 일치.
- 작업 폴더 생성 확인.

- 추가 회귀시험 `node tests/smoke.cjs`: **PASS** — 초기화, 도구 목록, PC 정보, 목록 조회, 읽기/쓰기, 명시적 덮어쓰기, 덮어쓰기 거부, 상대/절대 경로 탈출 차단, 임의 명령 도구 부재, 바이너리 차단, ping.
- 설치기 해시 불일치 모의 테스트: 다운로드 후 **거절(종료 코드 8)**, 설치 대상 파일 미생성.

## 아직 검증하지 않은 항목

- Node 없는 Windows PC에서 `winget install/upgrade` 및 UAC/재부팅 대응.
- 다른 Windows 사용자·OneDrive 리디렉션·조직 보안 정책의 설치.
- 사용자의 ChatGPT Desktop 호스트 실제 STDIO 서버 등록/호출.
- 사용자의 Platform 조직에서 Secure MCP Tunnel 생성, restricted runtime key, `doctor`, `run`.
- 사용자 ChatGPT 웹 계정에서 실제 `pc_info` 도구 호출.
- 허가된 폴더에 대한 장기 운영/다중 세션 및 권한 철회.

## 판정

**설치기와 로컬 MCP의 기본 기능은 검증됨.**
**상대방 ChatGPT 계정 연결은 미완료.**
모든 사용자가 한 번에 연결된다는 주장, 현재 컴퓨터의 외부 도구와 동일한 기능이라는 주장은 하지 않습니다.
