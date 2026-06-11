#!/usr/bin/env bash
# Hermes pre_llm_call hook: refresh the sprite task hold on every turn.
cat - >/dev/null   # discard stdin payload
curl -s --unix-socket /.sprite/api.sock \
     -H "Content-Type: application/json" \
     -X PUT http://sprite/v1/tasks/hermes-active \
     -d '{"expire":"5m"}' >/dev/null 2>&1
printf '{}\n'
