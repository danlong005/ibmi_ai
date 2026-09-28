---
name: rpgapi
description: Create and modify web applications built on RPGAPI, the Express-style ILE RPG web framework for IBM i (github.com/danlong005/RPGAPI). Use when the user asks to write, change, review, build, run or debug an RPGAPI app — a REST/JSON API, HTML pages from .erpg views, middleware, file uploads/downloads, static files, streaming exports, CORS, HTTPS — or mentions RPGAPI_*, rpgapi_h.rpgle, RPGAPI_App, RPGAPI_render, or .erpg templates.
argument-hint: [what to build or change]
---

Build or change an RPGAPI application for the following: $ARGUMENTS

## Your role

You are an expert ILE RPG developer who knows RPGAPI inside out. RPGAPI is a web
framework in the spirit of Express: you register **route procedures** and
**middleware** on an `RPGAPI_App`, call `RPGAPI_start`, and each HTTP request is
handed to your procedure as an `RPGAPI_Request` data structure; you return an
`RPGAPI_Response`. The server runs inside the program's own batch job.

Also follow the repo's `rpg` skill for general RPG style (free format,
`Monitor`, naming, 10-character object names). Where they differ, this skill
wins for RPGAPI code, notably: RPGAPI headers are IFS stream files included
with a quoted name (`/include 'rpgapi_h.rpgle'`), not `/Include ILESRC,MBR`.
When modifying an existing app, match that file's style (case, comment style,
helper names) over anything here.

## Reference files — read what the task needs before writing code

| File | Read it when |
|------|--------------|
| `references/api.md` | **Always** for new code: every procedure, data structure, constant, with exact types |
| `references/guides.md` | Routing rules, several jobs, stopping, keep-alive/timeouts, CORS, security headers, compression, client IP, bodies/uploads, auth, streaming, files, JSON, health checks, not-found/error handlers, logging, CCSIDs, HTTPS |
| `references/views.md` | Any HTML page from `.erpg` templates: tags, `RPGAPI_data`, layouts, includes, where views compile, errors |
| `references/patterns.md` | Complete, copy-ready starting points: JSON CRUD over SQL, HTML app with views + layout + form, API-key middleware, streaming export, uploads, production settings |

These were written from RPGAPI's `ApiDocumentation.md`, wiki and
`qrpglesrc/rpgapi_h.rpgle` (upstream commit `c897ac8`, Sept 2026). If a
procedure you need is not in them, or the compiler says a prototype does not
match, read the header in the RPGAPI clone on the IBM i (or
https://github.com/danlong005/RPGAPI/blob/main/qrpglesrc/rpgapi_h.rpgle) —
the header is the source of truth. Never invent `RPGAPI_*` procedures.

---

## The shape of every app

```rpgle
**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'

dcl-ds app likeds(RPGAPI_App);

clear app;                                     // always: settings at 0/blank get defaults
// settings (RPGAPI_setLogLevel, setCors, setNotFound, ...) go here, before start
RPGAPI_get(app : '/hello/{name}' : %paddr(hello));
RPGAPI_start(app : 8080);                      // blocks until the job ends / RPGAPI_shutdown

*inlr = *on;
return;


dcl-proc hello;                                // a ROUTE: request in, response out
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;   // inz, local: ALWAYS

   response.status = HTTP_OK;
   RPGAPI_setHeader(response : 'Content-Type' : 'text/plain; charset=utf-8');
   response.body = 'hello ' + RPGAPI_getParam(request : 'name');
   return response;
end-proc;
```

Middleware signature — returns `*on` to continue, `*off` to answer with `response`:
```rpgle
dcl-proc checkKey;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      response likeds(RPGAPI_Response);
   end-pi;
```

Error handler signature (for `RPGAPI_setErrorHandler`):
```rpgle
dcl-proc failed;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
      error likeds(RPGAPI_Error) const;
   end-pi;
```

The not-found handler (`RPGAPI_setNotFound`) is an ordinary route procedure.

---

## Rules that prevent real bugs — check every one

1. **`dcl-ds response likeds(RPGAPI_Response) inz;` inside each route.** Without
   `inz` the status is garbage; declared globally it leaks headers between
   requests. (Middleware receives `response` as a parameter — don't redeclare it.)
2. **`clear app;`** before registering anything.
3. **Register settings, routes and middleware before `RPGAPI_start`.** Nothing
   after `RPGAPI_start` runs until the server stops.
4. **The program takes no parameters** and must be safe to run once per job:
   with `RPGAPI_start(app : port : jobs)` every extra job re-runs the program
   from the top. Global variables (arrays, counters) are **per job**, not
   shared — use a table for shared state.
5. **Route order:** fixed segments before `{param}` in the same position
   (`/items/new` before `/items/{id}`). Routes match the whole path;
   middleware matches the path and everything below it.
6. **Params are text.** Convert inside `monitor` and answer 400 on failure:
   `id = %int(RPGAPI_getParam(request : 'id'));`.
7. **Trim fixed-length fields put in a body**: `response.body` is sent exactly as
   set, trailing blanks included (`%trim(row.name)`).
8. **Never build JSON by string concatenation of data.** Use SQL
   `JSON_OBJECT` / `JSON_ARRAYAGG` / `JSON_TABLE`, or `DATA-GEN`/`DATA-INTO` with
   YAJL. Concatenate only constants and numbers you produced. Set
   `Content-Type: application/json`.
9. **Escape HTML.** In views use `<%= %>` (escaped) for anything that came from a
   user or a table; `<%- %>` only for HTML you built. Outside views use
   `RPGAPI_writeHtml` / `RPGAPI_escapeHtml`.
10. **Bodies > 32,000 chars:** `request.body` holds only the first 32,000;
    read the rest with `RPGAPI_readBody` / `RPGAPI_readBodyBytes`, or
    `RPGAPI_saveBody`. Use one read method per request.
11. **Responses > 32,000 chars:** stream with `RPGAPI_beginResponse` →
    `RPGAPI_write` … → `RPGAPI_endResponse`, then still `return response;`.
    Set status/headers *before* `beginResponse`.
12. **Never use `part.filename` or a raw param as an IFS path.** Build the path
    yourself; `{param}` is one segment and `RPGAPI_sendFile` refuses `..`.
13. **Security**: guard `RPGAPI_shutdown` routes; `RPGAPI_checkUserProfile`
    burns `QMAXSIGN` attempts — HTTPS only; keep secrets (API keys, keystore
    passwords) out of source (data area / table).
14. **Health check routes** stay outside auth middleware (put auth on `/api`,
    not `*`).
15. **Don't name a data structure `page`** (reserved in RPG) — call the view
    model `model`.
16. **Limits**: 250 routes, 100 middleware, 20 static dirs, 100 response headers,
    header value 1,024 chars, `RPGAPI_getParam`/`getQueryParam` return up to
    1,024 chars, `getFormParam` up to 32,000.
17. **SQL programs**: `exec sql set option commit = *none;` (plus
    `closqlcsr = *endmod` when routes open cursors) and close every cursor
    you open. `sqlcode = 100` → 404.
18. HTTP status constants exist only for the codes in `api.md`; use a literal
    for others (`response.status = 303;`, `503`).

---

## Workflow in this repository

Source lives as members in the environment's source file (`ILESRC` by
default; `bin/.ibmi-config.json` → `File`). Local working copies are in
`source/` (e.g. `source/ORDERAPI.rpgle` or `.sqlrpgle`). RPGAPI itself must
already be built on the IBM i: a library (normally `RPGAPI`) holding the
`RPGAPI` service program and binding directory, plus a clone of the repo on
the IFS whose `qrpglesrc` directory holds `rpgapi_h.rpgle` and `http_h.rpgle`.

**Find the clone path** before compiling: look at the build comment of an
existing RPGAPI app in `source/` (its `INCDIR(...)`), check memory, or ask the
user. Do not guess.

### Creating a new app

1. Clarify only what you can't default: port (pick a free high port, e.g. 8080+,
   avoid the ones other apps use), JSON API vs HTML pages, the data source
   (table names / columns — look in `source/` then `production_source/ilesrc/`
   for DDS/SQL of the files), and auth needs.
2. Name the member (max 10 chars, uppercase), e.g. `ORDERAPI`. Use `.sqlrpgle`
   if it has embedded SQL.
3. Write `source/<NAME>.<ext>` starting from the matching template in
   `references/patterns.md`. Put a header comment with what it serves, the
   routes, how to build, run, stop and try it (curl lines) — as upstream
   examples do.
4. Upload: `/putsrc <NAME>` (see the `putsrc` skill).
5. Compile (see below), fix errors, recompile.
6. Run and test (see below). Show the user the curl output.

### Modifying an existing app

1. Read the current source in `source/` (download with `/cpysrc` only if the
   user says to). Read the view templates/copybooks too if it renders views.
2. Make the change following the rules above. Adding a route = a new
   `RPGAPI_<method>(...)` line **before `RPGAPI_start`** plus a new procedure.
   Changing a view's data structure = change the `_t.rpgleinc` copybook, then
   **recompile the route program too** (views recompile themselves; the
   program does not).
3. Upload, compile, **restart the server job** (a running job keeps the old
   program), test.

### Compiling

Use the `cmppgm` command / `bin/compile-pgm.sh` (or `.ps1`), passing the RPGAPI
`qrpglesrc` directory as the include directory, and `--sql` for `.sqlrpgle`:

```bash
bash bin/compile-pgm.sh ORDERAPI -e dev -i /home/<user>/RPGAPI/qrpglesrc
bash bin/compile-pgm.sh ORDERAPI -e dev -i /home/<user>/RPGAPI/qrpglesrc --sql
```
```powershell
pwsh -ExecutionPolicy Bypass -File bin/compile-pgm.ps1 -Pgm ORDERAPI -Environment dev -IncDir /home/<user>/RPGAPI/qrpglesrc [-SqlPgm]
```

- The script puts library `RPGAPI` on the library list, so
  `ctl-opt bnddir('RPGAPI')` resolves. If RPGAPI is built in another library,
  qualify it: `bnddir('MYLIB/RPGAPI')`. For SQL programs the `bnddir` **must**
  be in `ctl-opt` (CRTSQLRPGI has no BNDDIR parameter).
- The script accepts one include directory. A route program that also
  includes a view copybook (`layout_t.rpgleinc`, `orders_t.rpgleinc`) should
  include it by **absolute IFS path**:
  `/include '/home/<user>/myapp/views/orders_t.rpgleinc'`.
- **CCSID**: RPGAPI converts UTF-8 to/from the *job's* CCSID. Upstream builds
  apps with `TGTCCSID(*JOB)` (SQL: `CVTCCSID(*JOB)` +
  `COMPILEOPT('TGTCCSID(*JOB)')`). Compiling from a member defaults to the
  member's CCSID, which is fine when the source file's CCSID matches the CCSID
  the server job runs in. If `{param}` routes don't match or `[ ] { } @ \ |`
  come out wrong in responses, that mismatch is the cause — compile the
  command by hand with `TGTCCSID(*JOB)` and tell the user.
- Common compile errors: `RNF7030` name not defined (missing include / typo),
  `RNF7535`/`RNF7536` prototype mismatch (wrong param type — check `api.md`),
  `RNS9308`/`CPD5D1A` binding: `RPGAPI` bnddir not found (library list /
  qualification), `RNF0337` include not found (INCDIR path).

Manual equivalents, run over SSH with `system "..."` in qsh:
```
CRTBNDRPG PGM(MYLIB/MYAPP) SRCFILE(MYLIB/ILESRC) SRCMBR(MYAPP)
          INCDIR('/home/<user>/RPGAPI/qrpglesrc') TGTCCSID(*JOB) DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/MYAPP) SRCFILE(MYLIB/ILESRC) SRCMBR(MYAPP) CVTCCSID(*JOB)
           RPGPPOPT(*LVL2) INCDIR('/home/<user>/RPGAPI/qrpglesrc')
           COMPILEOPT('TGTCCSID(*JOB)') DBGVIEW(*SOURCE)
```

### Views (HTML templates) live on the IFS, not in members

`.erpg` templates and their `_t.rpgleinc` copybooks are stream files in the
directory given to `RPGAPI_setViews` (absolute path). Keep local copies under
`source/views/<APPNAME>/` and upload them with scp/sftp using the
environment's host, port and user from `bin/.ibmi-config.json`, e.g.
`scp -P <port> source/views/ORDERAPI/* <user>@<host>:/home/<user>/orderapi/views/`
(create the directory first with `ssh ... mkdir -p`). Templates are read as
UTF-8 regardless of the file's CCSID tag. Views compile themselves on first
request and whenever they change — no restart is needed for a template-only
change, but the job needs the ILE RPG compiler and authority to create `RV*`
programs in the views library. Check a template without a browser:
`CALL PGM(RPGAPI/ERPG) PARM('/abs/path/view.erpg' 'MYLIB')`.

### Running, testing, stopping

Run over SSH in qsh (`system "..."`), then test with curl from here:
```
SBMJOB CMD(CALL PGM(MYLIB/MYAPP)) JOB(MYAPP) JOBQ(QSYSNOMAX)   # JOBQ optional
curl -i http://<host>:<port>/<route>
ENDJOB JOB(MYAPP)                   # controlled: in-flight requests finish
ENDJOB JOB(MYAPP) OPTION(*IMMED)    # now
```
- Before starting, end any previous instance (`ENDJOB`) or the port is busy:
  `RPGAPI_start` then ends with `CPF9898 bind() failed ... Address already in use`.
- Give it a second or two after `SBMJOB` before curling.
- Shared systems (e.g. PUB400) may firewall arbitrary ports; if curl from
  here times out, curl from the IBM i itself over SSH:
  `curl -s -i http://localhost:<port>/...`.
- To see what happened, set `RPGAPI_setLogLevel(app : RPGAPI_LOG_DEBUG)` (or
  INFO), recompile, restart, and read the job log:
  ```sql
  SELECT message_timestamp, message_text
    FROM TABLE(QSYS2.JOBLOG_INFO('*/*/MYAPP')) WHERE message_text LIKE 'RPGAPI %'
  ```
  or find the job with `WRKACTJOB` / `QSYS2.ACTIVE_JOB_INFO(JOB_NAME_FILTER => 'MYAPP')`
  and use its qualified name `number/user/MYAPP`. A job that already ended
  leaves its log in a spooled file (`QPJOBLOG`).
- Turn logging back down to WARN before calling the work finished, unless the
  user wants it on.

Always leave the user with: the member(s) written, how it was compiled, the
job name/port it runs on, and the curl commands that prove it works (with
actual output if you ran them). Say plainly if you couldn't run or test it.

---

## Output checklist

1. `**free`, `ctl-opt ... bnddir('RPGAPI') dftactgrp(*no)`, `/include 'rpgapi_h.rpgle'`
2. `clear app;` → settings → middleware → routes (fixed before `{param}`) → `RPGAPI_start`
3. Every route: correct `dcl-pi`, local `response ... inz`, status set, `Content-Type` set, `return response`
4. JSON built by SQL or YAJL, never concatenated from data; HTML escaped
5. Params converted inside `monitor`, 400 on bad input, 404 on `sqlcode = 100`
6. JSON `setNotFound` / `setErrorHandler` for APIs; health route outside auth
7. Header comment: routes, build, run, stop, curl examples
8. Views: model DS in a shared `_t.rpgleinc`, `based(RPGAPI_data)` in the view, layout data first (`head likeds(layout_t)`)
