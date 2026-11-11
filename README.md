# Agent habits kit

Files to copy for the four habits from the talk "A coding agent you can leave alone". Each habit
below says what to do in a chat tool (ChatGPT, Claude, Gemini), in a code editor (GitHub Copilot,
Cursor, Claude Code), and when you start letting an agent run commands on its own. Every file is
meant to be copied and changed to fit your work.

Menu names in these tools change often. Each step links to the vendor's page; if a menu has moved,
follow the link. Links checked on 2026-11-11.

## 1. Write a rule after every failure.

When the tool gets something wrong, write one line about it, with the reason, in a list you keep.
The tool forgets everything between conversations, so the list is how a lesson carries over.
Start from [rules/starter-rules.md](rules/starter-rules.md): a template and eight sample rules,
each with the failure it was written after.

**In a chat tool**, put the list where the tool reads it at the start of every chat:

- ChatGPT: Settings > Personalization > Custom instructions
  ([help](https://help.openai.com/en/articles/8096356-chatgpt-custom-instructions)). For one
  project only: the project's ••• menu > Project settings
  ([help](https://help.openai.com/en/articles/10169521-projects-in-chatgpt)).
- Claude: Settings > Your Claude > Instructions
  ([help](https://support.claude.com/en/articles/10185728-understanding-claude-s-personalization-features)).
  For one project only: "Set project instructions" on the project page
  ([help](https://support.claude.com/en/articles/9519177-how-can-i-create-and-manage-projects)).
- Gemini: Settings > Personal context > Your instructions for Gemini
  ([help](https://support.google.com/gemini/answer/16598625?hl=en)). From 17 November 2026, Gems on
  personal accounts become skills ([help](https://support.google.com/gemini/answer/15146780?hl=en)).
- Any other tool: paste the list at the start of each conversation.

**In a code editor**, save the list as a file in your project:

- `AGENTS.md` in the project's top folder is read by GitHub Copilot, Cursor and many other tools
  ([agents.md](https://agents.md/)).
- GitHub Copilot also reads `.github/copilot-instructions.md`
  ([docs](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions)).
- Cursor also reads rule files in `.cursor/rules/` (they must end in `.mdc`), and has User Rules
  in its settings for all projects ([docs](https://cursor.com/docs/rules)).
- Claude Code reads `CLAUDE.md` in the project folder, and `~/.claude/CLAUDE.md` for all
  projects. If you already have `AGENTS.md`, put the line `@AGENTS.md` in `CLAUDE.md`
  ([docs](https://code.claude.com/docs/en/memory)).

**When the agent runs on its own**, the rule file is the same. The difference is that the agent
may skip a rule on a hard task, which is what habit 2 is for.

## 2. Prefer locks over requests.

A request in the prompt is a sign: on a hard task it gets skipped. A lock removes the option.

**In a chat tool**, there is nothing to lock in software, so remove the option yourself:

- Give the tool a copy, not the original: a copy of the spreadsheet, an export of the document.
- Give it read access, not the power to send, delete or pay.
- Where you cannot remove an option, make it need your approval each time.

**In a code editor** with an agent mode that runs commands, keep command approval on:

- GitHub Copilot in VS Code: keep the permission level on Manual permissions, the default. A
  `false` entry in `chat.tools.terminal.autoApprove` makes a command ask first, but does not block
  it ([docs](https://code.visualstudio.com/docs/agents/run/approvals)).
- Cursor: Settings > Agents > Approvals & Execution. To be asked before every command, use
  Allowlist with an empty list. Cursor's docs say its default, Auto-review, "is not a security
  boundary" ([docs](https://cursor.com/docs/agent/security/run-modes)).
- Claude Code: add commands you never want run to `"deny"` under `"permissions"` in your settings
  file, for example `"Bash(git push *)"` ([docs](https://code.claude.com/docs/en/permissions)).

**When the agent runs on its own**, use a lock that refuses a command and says what to do instead:
[agent/](agent/README.md) has one for Claude Code, with tests and a check that it is on.

## 3. Check the brief, then have a fresh reader check it again.

Before you hand a long task to an AI, or to a person, write the brief down and check it. Then
give it to a reader who has only the page. Whatever they stumble on, the one doing the work would
have had to guess at.

1. Audit it yourself, with [prompts/audit-the-brief.md](prompts/audit-the-brief.md). The prompt
   assumes there are at least two mistakes, so the tool looks for them.
2. Open a new conversation with no history, paste the corrected brief and
   [prompts/fresh-reader.md](prompts/fresh-reader.md), and fix what it would have to guess.

This works the same in a chat tool, a code editor, and for an agent that runs on its own. For an
agent, it matters most: nobody is there to answer its questions.

## 4. Ask for proof, not a report.

When the tool says it is done, ask to see the result: the file, the figure and where it came
from, the link, the check that passed. If it gives you a number, ask whether it was looked up
just now or remembered. Then try the result yourself once.
[prompts/show-me-proof.md](prompts/show-me-proof.md) is the prompt to paste.

**In a code editor**, ask for the command it ran and the output it got. "The tests pass" is a
report; the test output is proof.

**When the agent runs on its own**, put this in the rule file, so the proof is in its report
before you ask. The last two sample rules in [rules/starter-rules.md](rules/starter-rules.md) do
this.

## Keep a lessons notebook

When you correct the tool, have it write the lesson down as a short note: one lesson per note,
with the reason and what to do next time. [notebook/lesson-note.md](notebook/lesson-note.md) is
the template, with one example.

- In a chat tool: add the note to your list from habit 1. ChatGPT, Claude and Gemini also have
  memory features that remember things across chats; check what they saved in their settings
  ([ChatGPT](https://help.openai.com/en/articles/8590148-memory-faq),
  [Claude](https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context),
  [Gemini](https://support.google.com/gemini/answer/18617127?hl=en)).
- In a code editor: add the note to the rule file, or keep notes in a file the rule file points
  to. Claude Code writes its own notes ("auto memory", see its
  [docs](https://code.claude.com/docs/en/memory)); read them now and then and correct them.

## Licence

MIT. See [LICENSE](LICENSE).
