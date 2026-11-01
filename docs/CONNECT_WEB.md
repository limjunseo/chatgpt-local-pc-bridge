# 상대방 ChatGPT 웹 계정에 연결하는 절차

이 저장소의 MCP는 **Node.js가 실행하는 사용자 소유 로컬 프로세스**입니다. 외부 업체 MCP 서버로 요청을 보내지 않습니다. 웹 ChatGPT에서 이를 사용하려면 **OpenAI 자체 Secure MCP Tunnel**이 필요합니다.

## 전제 조건

- 대상 Windows PC 소유자의 설치 및 파일 접근 허가
- 대상 사용자의 **ChatGPT 계정에서 커스텀 MCP(개발자 모드) 연결 권한**
- 대상 사용자의 **OpenAI Platform 조직에서 터널 생성/사용 권한**과 연결되는 ChatGPT 워크스페이스
- 별도의 **restricted runtime API key** (`Tunnels Read + Use`), 생성·수정 담당자에게는 `Tunnels Read + Manage`
- 대상 PC의 outbound HTTPS 443; 인바운드 RDP 3389 개방 불필요

## 단계

1. 대상 사용자 PC에서 `INSTALL.cmd` 실행. Node.js 설치 및 로컬 `local-pc-mcp.cjs` 파일 생성 여부 확인.
2. 대상 사용자 또는 승인받은 관리자가 https://platform.openai.com/settings/organization/tunnels 에서 **대상 사용자 자신의 조직** 터널 생성. tunnel_id 확인.
3. OpenAI 공식 https://github.com/openai/tunnel-client/releases/latest 의 Windows 바이너리 다운로드, 검증. 반드시 `tunnel-client help quickstart`, `init --help`로 현재 버전 명령 확인.
4. 대상 사용자가 **자신의 계정**에서 restricted runtime API key 생성. 키는 절대 GitHub/채팅/지원자 화면/로그에 노출하지 않음.
5. 대상 사용자 PC에서 프로필을 설정. 예시의 경로·터널 ID는 **실제 값으로 직접** 변경:

```powershell
# Example ONLY. Configure key via a private approved secret management method.
# A new working directory contains the official tunnel-client.exe.
.\tunnel-client.exe init --sample sample_mcp_stdio_local --profile chatgpt-local-pc --tunnel-id YOUR_TUNNEL_ID --mcp-command 'node.exe "C:\Users\YOUR_USER\AppData\Local\ChatGPTLocalPCBridge\local-pc-mcp.cjs"'
.\tunnel-client.exe doctor --profile chatgpt-local-pc --explain
.\tunnel-client.exe run --profile chatgpt-local-pc
```

6. 대상 사용자가 자신의 https://chatgpt.com/plugins 에서 **Add custom MCP server → Tunnel**, 자신에게 허용된 터널을 선택하고 도구 목록 및 권한을 확인한 후 직접 승인.
7. ChatGPT에서 **`pc_info`** 조회. 결과의 hostname이 **상대방 PC**와 같은지 확인. 허가된 `ChatGPTLocalFiles` 폴더 안에서만 파일 조회·쓰기 동작 시험.

## 동작 중지

- 웹 연결은 `tunnel-client` 중지로 즉시 끊을 수 있습니다.
- 장기적인 접근 허가를 철회하려면 ChatGPT 플러그인을 비활성화/삭제하고 Platform runtime key를 폐기·교체하세요.
- 설치기는 백그라운드 자동 실행, 자격증명 보관, 권한 우회를 하지 않습니다.

**검증 범위:** 설치기 및 로컬 MCP 통신은 시험했으나 상대방 실제 Platform 터널·ChatGPT 계정까지의 E2E 연결은 직접 시험하지 못했습니다.

공식 가이드: https://developers.openai.com/api/docs/guides/secure-mcp-tunnels
