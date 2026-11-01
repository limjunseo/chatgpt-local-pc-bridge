# ChatGPT Local PC Bridge 검증 보고서 — 2026-11-01

## 구성 및 목표

- 자체 제작 로컬 STDIO MCP 서버: `local-pc-mcp.cjs`, **v1.1.0**, Node.js 내장 모듈만 사용
- Desktop Commander 외부 패키지·호스팅 MCP: **사용하지 않음**
- `list_processes`는 Windows 기본 `tasklist.exe`를 읽기 전용으로 호출
- 등록 도구 수: **정확히 11개** (테스트에서 이름까지 검증)
- 기본 작업 공간: `%USERPROFILE%\ChatGPTLocalFiles` (상대방 PC의 사용자 권한 내)
- **임의 CMD/PowerShell 명령, 프로그램 설치, 프로세스 종료, PC 전체 파일 접근은 미지원**
- ChatGPT 웹 사용 시 **별도 OpenAI Secure MCP Tunnel 및 대상 사용자 계정의 권한/인증 필요**

## 검증된 Windows 2단계 설치 (2026-11-01)

- 1단계 CMD 설치 파일은 GitHub **고정 커밋** `2bd05ed264a6c259f688567eb16e700c30e2dfe3`에서 받아 **CRLF 줄바꿈** 확인 후 실행함. `--dry-run`, `--help` 종료 코드 0.
- 별도 Windows TEMP 환경변수로 분리해 1단계 실제 설치 성공(종료 코드 0). 자체 MCP 소스, `SETUP-TUNNEL.ps1`, `tunnel-client.exe`, `START-TUNNEL.cmd` 설치 확인.
- 공식 `openai/tunnel-client` 릴리스 v0.0.19 Windows AMD64 ZIP 다운로드 및 GitHub 릴리스 `digest` SHA-256 확인, `tunnel-client.exe --version` 실행 성공. ZIP의 `cloudflared.exe`와 `cloudflared-manifest.json`도 별도 시험에서 함께 설치됨을 확인.
- 2단계 PowerShell 설치 스크립트는 GitHub **고정 커밋** `4ab0a7e22f8a0892eed22c273ecf9e29b9ece139`, 다운로드 SHA-256 `6DD28095BA7F0E51D649BF83EC4FDE8A11317AFF7781A1414651AD0D3FF1CA3C` 검증.
- 가짜(실제 API가 아닌) Tunnel ID·키를 가진 테스트 TXT로 **파일 파싱, MCP 명령 사전검사, 터널 프로필 생성** 성공(종료 코드 0). 실제 키로 외부 Platform 인증은 시도하지 않음.
- Windows 경로의 역슬래시·공백 때문에 `tunnel-client init`가 실패하는 문제를 발견하고, `node.exe` + 따옴표로 감싼 슬래시 경로로 수정해 실제 `init` 성공 확인.
- 한국어 바탕화면 파일명을 PowerShell 5.1에서 일관되게 처리하기 위해 유니코드 문자 코드로 조립.
- **실제 상대방 터널 ID/런타임 키로 `doctor`와 `run`을 호출한 성공 사례, ChatGPT 플러그인 생성 및 `pc_info` E2E 검증은 아직 없음.**
- 바탕화면 TXT는 API 키가 **평문**이므로 사용자가 직접 파일 보안을 관리해야 함. 스크립트는 키를 콘솔에 출력하거나 추가 평문 설정 파일에 저장하지 않음.

## 확정된 배포 버전

- 대상 저장소: https://github.com/limjunseo/chatgpt-local-pc-bridge
- 실제 MCP 소스 고정 커밋: `360eccfce6ebc6d6afbbe031d125f13cb7250e84`
- 해당 커밋의 `local-pc-mcp.cjs` **다운로드 파일** SHA-256:
  `29DF03940A61E692953464070CF1F4EC059FDEEFCA369AD49C58603D6B5FB0C2`
- `INSTALL.cmd`는 `main`이 아닌 **위 고정 커밋 URL**에서 MCP 소스를 내려받고 동일 SHA-256인지 확인
- 로컬 편집본과 GitHub 다운로드본은 줄 내용이 동일하나, Windows 줄바꿈 차이로 **파일 자체 SHA-256은 서로 다를 수 있음**. 설치기의 기대값은 다운로드된 배포 파일 기준
- GitHub `main` raw 주소에서 캐시된 구버전을 반환하는 경우가 실제 관찰돼 커밋 고정으로 개선함

## 이번에 실제 검증한 사항

- Windows/Node.js **24.13.1**에서 `node --check` 통과
- 로컬 STDIO MCP `initialize`, `tools/list`, `ping` 통과
- `tests/smoke.cjs` 실제 실행 **종료 코드 0**
- 11개 도구 이름 일치, PC 정보/목록/파일 읽기·쓰기/텍스트 교체/폴더 생성/이동/파일 정보·내용 검색/작은 바이너리 읽기/프로세스 조회 테스트
- 경로 이탈(절대·상대 경로) 거부, 기존 파일의 무승인 덮어쓰기 거부, 문자열 일치 수가 다른 편집 거부
- 명령 실행 도구가 없는 상태임을 검증
- 이전 설치기의 Node.js 검사, GitHub 다운로드, 해시 검증, 고의로 변경한 해시 거부(종료 코드 8), 원본 설치 후 문법 검사 성공을 확인
- 파일 내용 검색의 큰 파일 처리 시 파일명 검색으로 잘못 돌아가는 동작을 수정하고, 탐색 디렉터리 개수도 제한하도록 개선

- **고정 커밋 설치기**(커밋 `7a65b37f7a9d0c9698284a5fb4104eb90689923a`)를 별도 TEMP 환경에서 내려받아 실행: **설치 종료 0**, 고정 소스 SHA-256 일치, `node --check` 종료 0, 설치된 자체 MCP의 `tests/smoke.cjs` 종료 0. 이 테스트는 Windows 사용자 환경변수를 모의했으며 **별도 실제 Windows 계정의 E2E는 아님**.

## 아직 미검증 / 미구현

- **상대방의 실제 Windows 사용자 계정에서 설치하는 E2E** (현재 시험은 TEMP 환경변수로 분리한 테스트)
- Node.js가 없는 PC에서 `winget` 설치·업그레이드·UAC·재부팅
- 다른 Windows 사용자 계정/관리형 조직 PC/보안 정책에서 실행
- 실제 ChatGPT 데스크톱 STDIO 연결, 웹 OpenAI Secure MCP Tunnel의 `doctor/run`, 계정 승인 및 최종 도구 호출
- 기존 Local Desktop Commander의 전체 파일·명령·프로세스 기능 동등성
- 특수 경로, 링크·정션 및 동시 파일 접근에 대한 별도 보안 감사

## 판정

**제한된 자체 MCP 서버 및 주요 파일 도구: 테스트 통과.** 
**ChatGPT 계정 연결 및 완전한 PC 제어: 미완료.**

설치 파일 하나만으로 PC 전체 명령 실행이나 ChatGPT 계정 인증이 자동 완료된다고 설명하지 않습니다.
