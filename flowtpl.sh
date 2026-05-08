#!/usr/bin/env bash
# ╔══════════════════════════════════════════════╗
# ║   flowtpl  —  Flow Template Manager          ║
# ║   Save · Load · Share · Browse               ║
# ╚══════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/UIM"

# ═══════════════════════════════════════════════
# GREEN THEME — override accent colors
# ═══════════════════════════════════════════════

OR='\033[38;5;119m'   # lime green  (replaces orange as main accent)
OD='\033[38;5;71m'    # forest green (replaces orange dim)
BL='\033[38;5;114m'   # soft green  (replaces blue for badges)
GR='\033[38;5;156m'   # bright green (success)
CY='\033[38;5;121m'   # mint green  (replaces cyan)

# ═══════════════════════════════════════════════
# TEMPLATE STORAGE
# ═══════════════════════════════════════════════

TPL_DIR="$DATA/templates"
mkdir -p "$TPL_DIR"

TPL_EXT=".snflow"

# ═══════════════════════════════════════════════
# PROJECT HELPERS
# ═══════════════════════════════════════════════

# list all projects (directories inside DATA that have a connections file)
list_projects() {
  for d in "$DATA"/*/; do
    [[ -d "$d" && -f "${d}connections" ]] && basename "$d"
  done
}

# count nodes in a project
proj_node_count() {
  ls "$DATA/$1/nodes/"*.node 2>/dev/null | wc -l | tr -d ' '
}

# print project list table
show_projects() {
  tpl_hdr "available projects"
  echo ""
  local projs=()
  mapfile -t projs < <(list_projects)
  if [[ ${#projs[@]} -eq 0 ]]; then
    info "no projects found — create one in flow with: init <name>"
    echo ""; return 1
  fi
  printf "  ${GY}%-4s  %-22s  %s${RS}
" "#" "PROJECT" "NODES"
  echo -e "  ${GY}$(printf '─%.0s' {1..35})${RS}"
  local i=1
  for p in "${projs[@]}"; do
    local nc; nc=$(proj_node_count "$p")
    printf "  ${OR}%-4s${RS}  ${WH}%-22s${RS}  ${BL}%s nodes${RS}
" "$i" "$p" "$nc"
    i=$((i+1))
  done
  echo ""
}

# pick a project interactively — sets PICKED_PROJ
pick_project() {
  local prompt_msg="${1:-select project}"
  local projs=()
  mapfile -t projs < <(list_projects)
  [[ ${#projs[@]} -eq 0 ]] && { err "no projects found"; return 1; }

  show_projects
  echo -ne "  ${GL}${prompt_msg} (name or #): ${RS}"
  read -r pick

  # number pick
  if [[ "$pick" =~ ^[0-9]+$ ]]; then
    local idx=$((pick-1))
    if [[ $idx -ge 0 && $idx -lt ${#projs[@]} ]]; then
      PICKED_PROJ="${projs[$idx]}"
    else
      err "invalid number"; return 1
    fi
  else
    # name pick — validate it exists
    local found=0
    for p in "${projs[@]}"; do
      [[ "$p" == "$pick" ]] && { found=1; break; }
    done
    [[ $found -eq 0 ]] && { err "project '$pick' not found"; return 1; }
    PICKED_PROJ="$pick"
  fi
}

# ═══════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════

tpl_banner() {
  clear
  echo -e "\033[38;5;119m${BD}"
  echo -e "     ████████╗███████╗███╗   ███╗██████╗ ██╗      █████╗ ████████╗███████╗███████╗"
  echo -e "        ██╔══╝██╔════╝████╗ ████║██╔══██╗██║     ██╔══██╗╚══██╔══╝██╔════╝██╔════╝"
  echo -e "        ██║   █████╗  ██╔████╔██║██████╔╝██║     ███████║   ██║   █████╗  ███████╗"
  echo -e "        ██║   ██╔══╝  ██║╚██╔╝██║██╔═══╝ ██║     ██╔══██║   ██║   ██╔══╝  ╚════██║"
  echo -e "        ██║   ███████╗██║ ╚═╝ ██║██║     ███████╗██║  ██║   ██║   ███████╗███████║"
  echo -e "        ╚═╝   ╚══════╝╚═╝     ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚══════╝"
  echo -e "     ⬡  sn-flow template manager${RS}\033[38;5;71m"
  echo -e "────────────────────────────────────────────────────────────────────────────────────"
  echo -e "     share · save · load · browse${RS}"
  echo ""
}

# ═══════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════

tpl_hdr() {
  echo ""
  echo -e "  ${OR}${BD}── $* ${RS}${GY}────────────────────────────────${RS}"
}

tpl_list_files() {
  ls "$TPL_DIR/"*"$TPL_EXT" 2>/dev/null | xargs -I{} basename {} "$TPL_EXT"
}

tpl_exists() { [[ -f "$TPL_DIR/$1$TPL_EXT" ]]; }

tpl_meta_get() {
  local file="$TPL_DIR/$1$TPL_EXT" field="$2"
  grep "^#meta:${field}=" "$file" 2>/dev/null | head -1 | cut -d= -f2-
}

# ═══════════════════════════════════════════════
# CMD: save — save current project as template
# ═══════════════════════════════════════════════

cmd_tpl_save() {
  local tname="$1" desc="$2"
  [[ -z "$tname" ]] && { err "usage: save <template_name> [description]"; return; }

  # pick which project to save
  PICKED_PROJ=""
  pick_project "save from which project" || return
  use_proj "$PICKED_PROJ"
  require_init || return

  tpl_hdr "save template: $tname  (from: $PICKED_PROJ)"
  echo ""

  # description prompt if not provided
  if [[ -z "$desc" ]]; then
    echo -ne "  ${GL}description (optional): ${RS}"
    read -r desc
  fi

  local out="$TPL_DIR/${tname}${TPL_EXT}"
  local author; author=$(whoami 2>/dev/null || echo "unknown")
  local created; created=$(date '+%Y-%m-%d %H:%M:%S')
  local node_count; node_count=$(node_list | wc -l | tr -d ' ')

  {
    # ── file header ──────────────────────────
    echo "# ╔══════════════════════════════════════════════╗"
    echo "# ║   sn-flow template  ·  .snflow               ║"
    echo "# ╚══════════════════════════════════════════════╝"
    echo "#meta:name=${tname}"
    echo "#meta:description=${desc}"
    echo "#meta:author=${author}"
    echo "#meta:created=${created}"
    echo "#meta:source_project=${PROJ}"
    echo "#meta:nodes=${node_count}"
    echo "#meta:version=1"
    echo ""
    echo "# ════════════════════════════════════════════════"
    echo "# NODES"
    echo "# ════════════════════════════════════════════════"
    echo ""

    # dump each node
    for nname in $(node_list); do
      local ntype nsub nlang nbody
      ntype=$(node_type "$nname")
      nsub=$(node_subtype "$nname")
      nlang=$(node_lang "$nname")
      nbody=$(node_body "$nname")
      echo "NODE:${nname}"
      echo "TYPE:${ntype}"
      echo "SUB:${nsub}"
      echo "LANG:${nlang}"
      echo "BODY_START"
      echo "${nbody}"
      echo "BODY_END"
      echo ""
    done

    echo "# ════════════════════════════════════════════════"
    echo "# CONNECTIONS"
    echo "# ════════════════════════════════════════════════"
    echo ""
    cat "$CONNS" 2>/dev/null

  } > "$out"

  ok "saved: ${OR}${tname}${RS}  ${GY}→  ${WD}${out}${RS}"
  info "nodes: ${OR}${node_count}${RS}  ·  author: ${GL}${author}${RS}  ·  project: ${GL}${PROJ}${RS}"
  echo ""
  info "share with: ${OR}cp ${out} <destination>${RS}"
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: load — load a template into current/new project
# ═══════════════════════════════════════════════

cmd_tpl_load() {
  local tname="$1" target_proj="$2"
  [[ -z "$tname" ]] && { err "usage: load <template_name> [project_name]"; return; }
  tpl_exists "$tname" || { err "template '$tname' not found — try: ls"; return; }

  local file="$TPL_DIR/${tname}${TPL_EXT}"

  tpl_hdr "load template: $tname"
  echo ""

  # show template info
  local tdesc tauthor tcreated tnodes
  tdesc=$(tpl_meta_get "$tname" "description")
  tauthor=$(tpl_meta_get "$tname" "author")
  tcreated=$(tpl_meta_get "$tname" "created")
  tnodes=$(tpl_meta_get "$tname" "nodes")

  echo -e "  ${GL}description  ${RS}${WD}${tdesc:-none}${RS}"
  echo -e "  ${GL}author       ${RS}${OR}${tauthor}${RS}"
  echo -e "  ${GL}created      ${RS}${GY}${tcreated}${RS}"
  echo -e "  ${GL}nodes        ${RS}${OR}${tnodes}${RS}"
  echo ""

  # pick or enter target project
  echo ""
  echo -e "  ${GL}load into an existing project or type a new project name${RS}"
  echo ""
  local projs=()
  mapfile -t projs < <(list_projects)
  if [[ ${#projs[@]} -gt 0 ]]; then
    printf "  ${GY}%-4s  %-22s  %s${RS}
" "#" "PROJECT" "NODES"
    echo -e "  ${GY}$(printf '─%.0s' {1..35})${RS}"
    local i=1
    for p in "${projs[@]}"; do
      local nc; nc=$(proj_node_count "$p")
      printf "  ${OR}%-4s${RS}  ${WH}%-22s${RS}  ${BL}%s nodes${RS}
" "$i" "$p" "$nc"
      i=$((i+1))
    done
    echo ""
  fi
  echo -ne "  ${GL}project name or # (new name creates a fresh project): ${RS}"
  read -r target_proj
  [[ -z "$target_proj" ]] && { info "cancelled"; return; }

  # resolve number pick
  if [[ "$target_proj" =~ ^[0-9]+$ ]]; then
    local idx=$((target_proj-1))
    if [[ $idx -ge 0 && $idx -lt ${#projs[@]} ]]; then
      target_proj="${projs[$idx]}"
    else
      err "invalid number"; return
    fi
  fi

  # warn if project exists and has nodes
  use_proj "$target_proj"
  if node_exists "start" 2>/dev/null; then
    echo -ne "  ${OD}project '${target_proj}' already has nodes — overwrite? [y/N] ${RS}"
    read -r c
    [[ "$c" == "y" || "$c" == "Y" ]] || { info "cancelled"; return; }
    # wipe existing nodes and connections
    rm -f "$NODES"/*.node
    > "$CONNS"
  fi

  # parse and restore nodes
  local current_node="" current_type="" current_sub="" current_lang=""
  local in_body=0 body_lines=()
  local loaded_nodes=0

  while IFS= read -r line; do
    # skip comment/meta lines outside body
    if [[ $in_body -eq 0 && "$line" == \#* ]]; then continue; fi

    if [[ "$line" == NODE:* ]]; then
      current_node="${line#NODE:}"
    elif [[ "$line" == TYPE:* ]]; then
      current_type="${line#TYPE:}"
    elif [[ "$line" == SUB:* ]]; then
      current_sub="${line#SUB:}"
    elif [[ "$line" == LANG:* ]]; then
      current_lang="${line#LANG:}"
    elif [[ "$line" == "BODY_START" ]]; then
      in_body=1
      body_lines=()
    elif [[ "$line" == "BODY_END" ]]; then
      in_body=0
      # save the node
      local body_str
      body_str=$(printf '%s\n' "${body_lines[@]}")
      node_save "$current_node" "$current_type" "$current_sub" "$current_lang" "$body_str"
      loaded_nodes=$((loaded_nodes+1))
      current_node="" current_type="" current_sub="" current_lang=""
    elif [[ $in_body -eq 1 ]]; then
      body_lines+=("$line")
    fi
  done < <(grep -v "^# ═\|^# NODES\|^# CONNECTIONS\|^$" "$file")

  # restore connections (lines after # CONNECTIONS section, no # prefix)
  local in_conns=0
  while IFS= read -r line; do
    [[ "$line" == "# CONNECTIONS" ]] && { in_conns=1; continue; }
    [[ $in_conns -eq 1 && -n "$line" && "$line" != \#* ]] && echo "$line" >> "$CONNS"
  done < <(grep -v "^# ═\|^# ║\|^# ╔\|^# ╚\|^#meta:" "$file")

  ok "loaded: ${OR}${tname}${RS}  →  project ${OR}${target_proj}${RS}"
  info "nodes restored: ${OR}${loaded_nodes}${RS}"
  info "open flow and use: ${OR}switch ${target_proj}${RS}  to run it"
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: import — import a .snflow file from path
# ═══════════════════════════════════════════════

cmd_tpl_import() {
  local path="$1"
  [[ -z "$path" ]] && { err "usage: import <path/to/file.snflow>"; return; }
  [[ -f "$path" ]] || { err "file not found: $path"; return; }

  tpl_hdr "import template"
  echo ""

  local tname
  tname=$(basename "$path" "$TPL_EXT")

  if tpl_exists "$tname"; then
    echo -ne "  ${OD}template '$tname' already exists — overwrite? [y/N] ${RS}"
    read -r c
    [[ "$c" == "y" || "$c" == "Y" ]] || { info "cancelled"; return; }
  fi

  cp "$path" "$TPL_DIR/${tname}${TPL_EXT}"

  local tdesc tauthor tcreated
  tdesc=$(tpl_meta_get "$tname" "description")
  tauthor=$(tpl_meta_get "$tname" "author")
  tcreated=$(tpl_meta_get "$tname" "created")

  ok "imported: ${OR}${tname}${RS}"
  echo -e "  ${GL}description  ${RS}${WD}${tdesc:-none}${RS}"
  echo -e "  ${GL}author       ${RS}${OR}${tauthor}${RS}"
  echo -e "  ${GL}created      ${RS}${GY}${tcreated}${RS}"
  echo ""
  info "use: ${OR}load ${tname}${RS}"
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: export — export template to a shareable path
# ═══════════════════════════════════════════════

cmd_tpl_export() {
  local tname="$1" dest="$2"
  [[ -z "$tname" ]] && { err "usage: export <template_name> [destination_path]"; return; }
  tpl_exists "$tname" || { err "template '$tname' not found — try: ls"; return; }

  [[ -z "$dest" ]] && dest="./${tname}${TPL_EXT}"

  cp "$TPL_DIR/${tname}${TPL_EXT}" "$dest"
  ok "exported: ${OR}${tname}${RS}  →  ${WD}${dest}${RS}"
  info "share this file with others — they can import with: ${OR}import <path>${RS}"
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: ls — list all saved templates
# ═══════════════════════════════════════════════

cmd_tpl_ls() {
  tpl_hdr "saved templates"
  echo ""

  local tpls=()
  mapfile -t tpls < <(tpl_list_files)

  if [[ ${#tpls[@]} -eq 0 ]]; then
    info "no templates saved yet"
    info "save one with: ${OR}save <name>${RS}"
    echo ""; return
  fi

  printf "  ${GY}%-22s  %-28s  %-12s  %s${RS}\n" "NAME" "DESCRIPTION" "AUTHOR" "CREATED"
  echo -e "  ${GY}$(printf '─%.0s' {1..75})${RS}"

  for tname in "${tpls[@]}"; do
    local tdesc tauthor tcreated tnodes
    tdesc=$(tpl_meta_get "$tname" "description")
    tauthor=$(tpl_meta_get "$tname" "author")
    tcreated=$(tpl_meta_get "$tname" "created")
    tnodes=$(tpl_meta_get "$tname" "nodes")
    # truncate description
    [[ ${#tdesc} -gt 26 ]] && tdesc="${tdesc:0:23}..."
    printf "  ${OR}%-22s${RS}  ${WD}%-28s${RS}  ${GL}%-12s${RS}  ${GY}%s${RS}  ${BL}%s nodes${RS}\n" \
      "$tname" "${tdesc:--}" "${tauthor:-?}" "${tcreated:--}" "${tnodes:-?}"
  done
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: show — inspect a template
# ═══════════════════════════════════════════════

cmd_tpl_show() {
  local tname="$1"
  [[ -z "$tname" ]] && { err "usage: show <template_name>"; return; }
  tpl_exists "$tname" || { err "template '$tname' not found — try: ls"; return; }

  tpl_hdr "template: $tname"
  echo ""

  echo -e "  ${GL}name         ${RS}${OR}$(tpl_meta_get "$tname" "name")${RS}"
  echo -e "  ${GL}description  ${RS}${WD}$(tpl_meta_get "$tname" "description")${RS}"
  echo -e "  ${GL}author       ${RS}${OR}$(tpl_meta_get "$tname" "author")${RS}"
  echo -e "  ${GL}created      ${RS}${GY}$(tpl_meta_get "$tname" "created")${RS}"
  echo -e "  ${GL}source proj  ${RS}${GL}$(tpl_meta_get "$tname" "source_project")${RS}"
  echo -e "  ${GL}nodes        ${RS}${OR}$(tpl_meta_get "$tname" "nodes")${RS}"
  echo -e "  ${GL}file         ${RS}${WD}${TPL_DIR}/${tname}${TPL_EXT}${RS}"
  echo ""

  # list node names
  local nnames=()
  while IFS= read -r line; do
    [[ "$line" == NODE:* ]] && nnames+=("${line#NODE:}")
  done < "$TPL_DIR/${tname}${TPL_EXT}"

  if [[ ${#nnames[@]} -gt 0 ]]; then
    echo -e "  ${GL}node list:${RS}"
    for nn in "${nnames[@]}"; do
      echo -e "    ${GY}·${RS}  ${OR}${nn}${RS}"
    done
  fi
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: projects — list all flow projects
# ═══════════════════════════════════════════════

cmd_tpl_projects() {
  local projs=()
  mapfile -t projs < <(list_projects)
  if [[ ${#projs[@]} -eq 0 ]]; then
    info "no projects found — create one in flow with: ${OR}init <name>${RS}"
    echo ""; return
  fi
  tpl_hdr "flow projects"
  echo ""
  printf "  ${GY}%-4s  %-22s  %-10s  %s${RS}
" "#" "PROJECT" "NODES" "ACTIONS"
  echo -e "  ${GY}$(printf '─%.0s' {1..60})${RS}"
  local i=1
  for p in "${projs[@]}"; do
    local nc; nc=$(proj_node_count "$p")
    printf "  ${OR}%-4s${RS}  ${WH}%-22s${RS}  ${BL}%-10s${RS}  ${GY}save %s · load → %s${RS}
"       "$i" "$p" "${nc} nodes" "$p" "$p"
    i=$((i+1))
  done
  echo ""
  info "save a project  : ${OR}save <template_name>${RS}"
  info "load a template : ${OR}load <template_name>${RS}"
  info "list templates  : ${OR}ls${RS}"
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: rm — delete a template
# ═══════════════════════════════════════════════

cmd_tpl_rm() {
  local tname="$1"
  [[ -z "$tname" ]] && { err "usage: rm <template_name>"; return; }
  tpl_exists "$tname" || { err "template '$tname' not found"; return; }

  echo -ne "  ${OD}delete template '${tname}'? [y/N] ${RS}"
  read -r c
  [[ "$c" == "y" || "$c" == "Y" ]] || { info "cancelled"; return; }

  rm -f "$TPL_DIR/${tname}${TPL_EXT}"
  ok "deleted: $tname"
  echo ""
}

# ═══════════════════════════════════════════════
# HELP
# ═══════════════════════════════════════════════

cmd_tpl_help() {
  tpl_hdr "flowtpl commands"
  echo ""
  local cmds=(
    "save <name> [desc]"         "save current flow project as a template"
    "load <name> [project]"      "load a template into a project"
    "import <path.snflow>"       "import a shared .snflow file"
    "export <name> [dest]"       "export template to a shareable file"
    "ls"                         "list all saved templates"
    "show <name>"                "inspect template details and node list"
    "rm <name>"                  "delete a saved template"
    "projects"                   "list all flow projects with node count and actions"
    "help"                       "this screen"
    "exit / quit"                "exit flowtpl"
  )
  local i=0
  while [[ $i -lt ${#cmds[@]} ]]; do
    printf "  ${OR}%-32s${RS}${WD}%s${RS}\n" "${cmds[$i]}" "${cmds[$((i+1))]}"
    i=$((i+2))
  done

  echo ""
  tpl_hdr "quick workflow"
  echo ""
  echo -e "  ${GL}# 1. open flow, build your workflow, then open flowtpl${RS}"
  echo -e "  ${OR}  bash flowtpl${RS}"
  echo ""
  echo -e "  ${GL}# 2. save current project as template${RS}"
  echo -e "  ${OR}  save mytemplate \"a starter workflow for X\"${RS}"
  echo ""
  echo -e "  ${GL}# 3. export to share with others${RS}"
  echo -e "  ${OR}  export mytemplate ~/Desktop/mytemplate.snflow${RS}"
  echo ""
  echo -e "  ${GL}# 4. recipient imports and loads it${RS}"
  echo -e "  ${OR}  import ~/Downloads/mytemplate.snflow${RS}"
  echo -e "  ${OR}  load mytemplate mynewproject${RS}"
  echo ""
  echo -e "  ${GL}# 5. switch to it inside flow${RS}"
  echo -e "  ${OR}  switch mynewproject${RS}"
  echo ""
  echo -e "  ${GY}templates are stored at: ${WD}${TPL_DIR}${RS}"
  echo ""
}

# ═══════════════════════════════════════════════
# PROMPT
# ═══════════════════════════════════════════════

tpl_prompt() {
  local count=0
  count=$(tpl_list_files 2>/dev/null | wc -l | tr -d ' ')
  local badge="${GY}${count} template(s)${RS}"
  echo ""
  echo -ne "  ${badge}  ${OR}${BD}▶${RS} "
}

# ═══════════════════════════════════════════════
# MAIN REPL
# ═══════════════════════════════════════════════

main() {
  tpl_banner
  info "type ${OR}help${RS}${WD} for commands  ·  templates: ${GL}${TPL_DIR}${RS}"
  echo ""

  local count=0
  count=$(tpl_list_files 2>/dev/null | wc -l | tr -d ' ')
  local pcount=0
  pcount=$(list_projects | wc -l | tr -d ' ')
  if [[ $count -gt 0 ]]; then
    info "${count} template(s) saved  ·  ${pcount} project(s) available"
  else
    info "no templates yet  ·  ${pcount} project(s) available"
    info "run ${OR}projects${RS}${WD} to see them, then ${OR}save <name>${RS}${WD} to create a template"
  fi
  echo ""

  while true; do
    tpl_prompt
    read -r input
    [[ -z "$input" ]] && continue

    local cmd arg1 arg2 rest
    read -r cmd arg1 arg2 rest <<< "$input"

    case "$cmd" in
      save)           cmd_tpl_save   "$arg1" "$arg2 $rest" ;;
      load)           cmd_tpl_load   "$arg1" "$arg2" ;;
      import)         cmd_tpl_import "$arg1" ;;
      export)         cmd_tpl_export "$arg1" "$arg2" ;;
      ls|list)        cmd_tpl_ls ;;
      show)           cmd_tpl_show   "$arg1" ;;
      rm|del)         cmd_tpl_rm     "$arg1" ;;
      projects|proj)  cmd_tpl_projects ;;
      clear)          tpl_banner; info "type ${OR}help${RS}${WD} for commands"; echo "" ;;
      help|h|\?)      cmd_tpl_help ;;
      exit|quit|q)    echo -e "\n  ${GY}bye.${RS}\n"; exit 0 ;;
      *)              err "unknown command: $cmd  (type help)" ;;
    esac
  done
}

main "$@"
