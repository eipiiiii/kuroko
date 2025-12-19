# Kuroko Project Overview

## Mandatory Workflow

Before ANY code modification:

1. **Check if task doc exists** for this feature/fix
2. **If not, CREATE ONE** in `.tasks/TASK-XXX-description.md`
3. **Fill out the template** completely
4. **Show to user** and wait for approval
5. **Begin implementation** only after approval
6. **Update task status** as you progress
7. **After completion**, ask user:

タスク[TASK-XXX]が完了しました。
以下が実装されました:

変更内容1

変更内容2

.tasks/TASK-XXX-xxx.mdを削除してよろしいですか?
削除する場合は「はい」、保持する場合は「いいえ」と返信してください。

text

8. **Delete only if user confirms** with「はい」

## File Size Limits

Keep files under **300 lines** [web:2]:
- If file exceeds limit, propose refactoring into modules
- Extract protocols to separate files
- Use extensions for protocol conformance

## Context Priority

When context window is limited, prioritize:
1. AGENTS.md (always load)
2. Current task doc in `.tasks/`
3. Relevant source files
4. Test files

## AGENTS.md Update Protocol

### Recognition Triggers

If you notice any of the following while working:

- ❓ Information missing from AGENTS.md that would have helped you
- 🔄 Pattern you're using repeatedly that isn't documented
- ⚠️ Misleading or outdated information in AGENTS.md
- 💡 Better way to explain existing concepts

**DO NOT immediately update AGENTS.md.** Follow the protocol below:

### Mandatory Steps

1. **Pause your current task**

2. **Create update proposal**:
   ```
   📋 AGENTS.md更新提案

   【トリガー】
   現在のタスク中に[XXX]の情報が不足していることに気づきました

   【提案する変更】
   セクション: [セクション名]

   変更前:
   ```
   [現在の記述]
   ```

   変更後:
   ```
   [提案する記述]
   ```

   【期待される効果】
   - 今後同様のタスクで[XXX]が明確になる
   - [YYY]の時間が短縮される

   この変更を実施してよろしいですか？
   ```

3. **Wait for user response**:
   - 「はい」→ Create task doc `.tasks/TASK-XXX-update-agents-md.md`
   - 「いいえ」→ Continue with current task, no changes
   - 「修正して」→ Revise proposal based on feedback

4. **If approved, execute update**:
   - Update AGENTS.md
   - Update version table
   - Commit with message: `[AGENTS.md] Description of change`
   - Complete task doc and request deletion permission

### Update Quality Standards

AGENTS.md changes must:

- ✅ Add value (not just rephrasing)
- ✅ Be verified by actual development experience
- ✅ Include concrete examples when introducing patterns
- ✅ Maintain consistency with existing `.clinerules/` files
- ❌ Never contradict user-approved architecture decisions
- ❌ Never remove information without user approval
