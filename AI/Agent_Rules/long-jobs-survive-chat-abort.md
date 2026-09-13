# Long jobs — survive chat abort

## Problem

A multi-hour job started under an AI chat / agent terminal dies when that terminal aborts. Workers may linger briefly; the queue stalls without a watcher.

## Mandatory

| Event | Do |
|-------|-----|
| Agent shell aborts, errors, or exits | Check process + state file. If the watcher is dead or state is frozen → **restart** (do not only report). |
| Starting a pool / overnight job | Prefer **detached** start (`Start-Process`, separate console, or scheduled task). |
| “Briefly inform the user” after abort | Inform **and** verify/restart in the same turn. |

## Forbidden

| Do not | Why |
|--------|-----|
| Treat “task aborted” as information-only | Job may be dead |
| Assume orphan workers will finish the queue | Without the watcher, remaining jobs never start |
| Tie a multi-hour rebuild only to chat blocking | Chat abort kills the watcher |
