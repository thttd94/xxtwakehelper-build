# Durable memory

## OpenClaw / Telegram recovery context
- Khi OpenClaw seems "treo" but web UI is recoverable, inspect `telegramlite` separately; Telegram hangs can be isolated from the main webchat agent.
- Một ghi nhớ tên riêng: bot Telegram 2 sẽ làm việc với **Mai Ngân Xinh đẹp**; khi nhắc tới người này thì luôn gọi đúng đầy đủ như vậy.
- A recurring failure pattern exists where the Telegram direct session for peer `2039938948` grows near the context ceiling (`~123k/128k`) and likely needs a hard reset/quarantine of both the direct and slash session transcripts to fully recover responsiveness.
