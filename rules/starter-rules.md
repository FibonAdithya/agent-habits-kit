# Starter rules

A rule file is a short list of how the AI should work, which it reads at the start of every
conversation. AI tools forget everything between conversations, so this list is how a lesson
carries over to the next day.

Write a rule after every failure. Keep each one short, and keep the reason next to it: the reason
lets the AI apply the rule to a case you did not foresee.

## Template

Copy this block for each new rule.

```
- RULE: <what to do, or never do, in one line>
  WHY: <what goes wrong otherwise>
  WRITTEN AFTER: <the failure that made you write it, in one line>
```

## Sample rules

These come from the talk. They are written for an AI that works on code, but the shape is what
matters: one line for the rule, one for the reason, one for what happened. Keep the ones that fit
your work, and replace the rest with your own.

```
- RULE: Name each file you save. Never save everything in the folder at once.
  WHY: "Everything" includes files that were never meant to be saved.
  WRITTEN AFTER: a "save everything" step took in 398 files, 85 MB of build leftovers, including
  a file with a private folder path in it.

- RULE: Never stop programs by name. Stop the exact program you started.
  WHY: A name can match programs you did not mean, including the AI's own session.
  WRITTEN AFTER: stopping programs by name stopped the AI's own session in the middle of a task.

- RULE: When two sets of changes conflict, settle each conflict. Never keep one whole version.
  WHY: Keeping one whole version also drops the other version's changes that did not conflict.
  WRITTEN AFTER: keeping one whole version silently threw away work.

- RULE: Check the connection once before uploading work. If an upload hangs, switch to another
  route instead of trying the same way again.
  WHY: Some networks fail without reporting an error.
  WRITTEN AFTER: wifi with a login page silently broke uploads for hours.

- RULE: A change is not done until every automatic check on it has passed.
  WHY: Work handed over with checks still running leaves the last check to someone else.
  WRITTEN AFTER: I asked for it after receiving work whose checks had not finished.

- RULE: Get to a real run as early as it is safe to. Count several passed reviews as weak
  evidence next to one real run.
  WHY: Reading work finds different problems from running it.
  WRITTEN AFTER: several rounds of careful review approved work that broke on its first real run.

- RULE: Do not say something is impossible, missing or already true without running the check
  that shows it. Report it as "I ran X, got Y", with the check shown.
  WHY: A claim without the check is a guess that sounds like a fact.
  EXAMPLE IT PREVENTS: "this cannot be built here", said without trying to build it.

- RULE: Every number says whether it was measured just now or estimated.
  WHY: A figure carries more authority than a sentence, and readers believe it.
  EXAMPLE IT PREVENTS: a figure from an earlier run, or from memory, reported as if just checked.
```

## Where to put the file

See the [README](../README.md#1-write-a-rule-after-every-failure) for where each tool reads it.
