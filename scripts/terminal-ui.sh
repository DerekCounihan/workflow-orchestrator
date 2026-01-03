#!/bin/bash
# Workflow Orchestrator - Terminal UI Helpers
# Provides colorful status output for workflow progress
#
# NOTE: All UI output goes to stderr to avoid corrupting JSON output on stdout.
# Claude Code hooks require JSON on stdout for structured control.

# Helper function: output to stderr
ui_print() {
  echo -e "$@" >&2
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Bold
BOLD='\033[1m'
DIM='\033[2m'

# Box drawing characters
BOX_TL="╔"
BOX_TR="╗"
BOX_BL="╚"
BOX_BR="╝"
BOX_H="═"
BOX_V="║"
BOX_SEP="╠"
BOX_END="╣"

# Icons (using Unicode)
ICON_CHECK="✓"
ICON_CROSS="✗"
ICON_ARROW="→"
ICON_GEAR="⚙"
ICON_CLOCK="⏱"
ICON_LOOP="↻"
ICON_PAUSE="⏸"
ICON_PLAY="▶"
ICON_STOP="⏹"
ICON_STAR="★"
ICON_DOT="●"
ICON_EMPTY="○"

# Print a horizontal line
print_line() {
  local width="${1:-60}"
  local char="${2:-─}"
  printf '%*s\n' "$width" '' | tr ' ' "$char" >&2
}

# Print a boxed header
print_header() {
  local title="$1"
  local width=60
  local padding=$(( (width - ${#title} - 2) / 2 ))

  ui_print ""
  ui_print "${CYAN}${BOX_TL}$(printf '%*s' $((width-2)) '' | tr ' ' "$BOX_H")${BOX_TR}${NC}"
  ui_print "${CYAN}${BOX_V}${NC}$(printf '%*s' $padding '')${BOLD}${WHITE}$title${NC}$(printf '%*s' $((width - padding - ${#title} - 2)) '')${CYAN}${BOX_V}${NC}"
  ui_print "${CYAN}${BOX_BL}$(printf '%*s' $((width-2)) '' | tr ' ' "$BOX_H")${BOX_BR}${NC}"
}

# Print workflow status banner
print_workflow_status() {
  local workflow_name="$1"
  local phase="$2"
  local step="$3"
  local step_name="$4"
  local iteration="$5"
  local max_iteration="$6"
  local total_iterations="$7"

  ui_print ""
  ui_print "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
  ui_print "${CYAN}│${NC}  ${BOLD}${MAGENTA}${ICON_GEAR} WORKFLOW ORCHESTRATOR${NC}                                 ${CYAN}│${NC}"
  ui_print "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
  ui_print "${CYAN}│${NC}  ${WHITE}Workflow:${NC} ${YELLOW}$workflow_name${NC}$(printf '%*s' $((38 - ${#workflow_name})) '')${CYAN}│${NC}"
  ui_print "${CYAN}│${NC}  ${WHITE}Phase:${NC}    ${BLUE}$phase${NC}$(printf '%*s' $((41 - ${#phase})) '')${CYAN}│${NC}"
  ui_print "${CYAN}│${NC}  ${WHITE}Step:${NC}     ${GREEN}$step${NC} - $step_name$(printf '%*s' $((28 - ${#step} - ${#step_name})) '')${CYAN}│${NC}"
  ui_print "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
  ui_print "${CYAN}│${NC}  ${WHITE}Step Iteration:${NC}  ${BOLD}$iteration${NC} / $max_iteration$(printf '%*s' $((32 - ${#iteration} - ${#max_iteration})) '')${CYAN}│${NC}"
  ui_print "${CYAN}│${NC}  ${WHITE}Total Iterations:${NC} ${BOLD}$total_iterations${NC}$(printf '%*s' $((32 - ${#total_iterations})) '')${CYAN}│${NC}"
  ui_print "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
  ui_print ""
}

# Print step completion banner
print_step_complete() {
  local step="$1"
  local step_name="$2"
  local iterations_used="$3"

  ui_print ""
  ui_print "${GREEN}┌────────────────────────────────────────────────────────────┐${NC}"
  ui_print "${GREEN}│${NC}  ${BOLD}${GREEN}${ICON_CHECK} STEP COMPLETE${NC}                                         ${GREEN}│${NC}"
  ui_print "${GREEN}├────────────────────────────────────────────────────────────┤${NC}"
  ui_print "${GREEN}│${NC}  ${WHITE}Step:${NC} ${CYAN}$step${NC} - $step_name$(printf '%*s' $((35 - ${#step} - ${#step_name})) '')${GREEN}│${NC}"
  ui_print "${GREEN}│${NC}  ${WHITE}Iterations:${NC} ${YELLOW}$iterations_used${NC}$(printf '%*s' $((38 - ${#iterations_used})) '')${GREEN}│${NC}"
  ui_print "${GREEN}└────────────────────────────────────────────────────────────┘${NC}"
  ui_print ""
}

# Print phase completion banner
print_phase_complete() {
  local phase="$1"
  local phase_name="$2"
  local steps_completed="$3"

  ui_print ""
  ui_print "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
  ui_print "${BLUE}║${NC}  ${BOLD}${BLUE}${ICON_STAR} PHASE COMPLETE${NC}                                        ${BLUE}║${NC}"
  ui_print "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
  ui_print "${BLUE}║${NC}  ${WHITE}Phase:${NC} ${MAGENTA}$phase${NC} - $phase_name$(printf '%*s' $((35 - ${#phase} - ${#phase_name})) '')${BLUE}║${NC}"
  ui_print "${BLUE}║${NC}  ${WHITE}Steps Completed:${NC} ${GREEN}$steps_completed${NC}$(printf '%*s' $((33 - ${#steps_completed})) '')${BLUE}║${NC}"
  ui_print "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  ui_print ""
}

# Print workflow completion banner
print_workflow_complete() {
  local workflow_name="$1"
  local total_iterations="$2"
  local phases_completed="$3"

  ui_print ""
  ui_print "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
  ui_print "${MAGENTA}║${NC}                                                            ${MAGENTA}║${NC}"
  ui_print "${MAGENTA}║${NC}     ${BOLD}${GREEN}${ICON_CHECK}${ICON_CHECK}${ICON_CHECK}  WORKFLOW COMPLETE  ${ICON_CHECK}${ICON_CHECK}${ICON_CHECK}${NC}                        ${MAGENTA}║${NC}"
  ui_print "${MAGENTA}║${NC}                                                            ${MAGENTA}║${NC}"
  ui_print "${MAGENTA}╠════════════════════════════════════════════════════════════╣${NC}"
  ui_print "${MAGENTA}║${NC}  ${WHITE}Workflow:${NC}         ${YELLOW}$workflow_name${NC}$(printf '%*s' $((30 - ${#workflow_name})) '')${MAGENTA}║${NC}"
  ui_print "${MAGENTA}║${NC}  ${WHITE}Total Iterations:${NC} ${CYAN}$total_iterations${NC}$(printf '%*s' $((30 - ${#total_iterations})) '')${MAGENTA}║${NC}"
  ui_print "${MAGENTA}║${NC}  ${WHITE}Phases Completed:${NC} ${GREEN}$phases_completed${NC}$(printf '%*s' $((30 - ${#phases_completed})) '')${MAGENTA}║${NC}"
  ui_print "${MAGENTA}║${NC}                                                            ${MAGENTA}║${NC}"
  ui_print "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
  ui_print ""
}

# Print checkpoint/pause banner
print_checkpoint() {
  local step="$1"
  local step_name="$2"

  ui_print ""
  ui_print "${YELLOW}┌────────────────────────────────────────────────────────────┐${NC}"
  ui_print "${YELLOW}│${NC}  ${BOLD}${YELLOW}${ICON_PAUSE} CHECKPOINT - AWAITING INPUT${NC}                         ${YELLOW}│${NC}"
  ui_print "${YELLOW}├────────────────────────────────────────────────────────────┤${NC}"
  ui_print "${YELLOW}│${NC}  ${WHITE}Step:${NC} ${CYAN}$step${NC} - $step_name$(printf '%*s' $((35 - ${#step} - ${#step_name})) '')${YELLOW}│${NC}"
  ui_print "${YELLOW}│${NC}                                                            ${YELLOW}│${NC}"
  ui_print "${YELLOW}│${NC}  ${DIM}Please review and provide your response...${NC}               ${YELLOW}│${NC}"
  ui_print "${YELLOW}└────────────────────────────────────────────────────────────┘${NC}"
  ui_print ""
}

# Print gate check status
print_gate_check_start() {
  local gate_type="$1"

  ui_print ""
  ui_print "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
  ui_print "${CYAN}│${NC}  ${BOLD}${CYAN}${ICON_GEAR} RUNNING GATE CHECKS${NC}                                    ${CYAN}│${NC}"
  ui_print "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
  ui_print "${CYAN}│${NC}  ${WHITE}Type:${NC} ${YELLOW}$gate_type${NC}$(printf '%*s' $((44 - ${#gate_type})) '')${CYAN}│${NC}"
  ui_print "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
}

print_gate_check_pass() {
  ui_print "${GREEN}│${NC}  ${GREEN}${ICON_CHECK}${NC} All gate checks ${BOLD}${GREEN}PASSED${NC}                                  ${GREEN}│${NC}"
  ui_print "${GREEN}└────────────────────────────────────────────────────────────┘${NC}"
  ui_print ""
}

print_gate_check_fail() {
  ui_print "${RED}│${NC}  ${RED}${ICON_CROSS}${NC} Gate checks ${BOLD}${RED}FAILED${NC} - Fix issues to proceed              ${RED}│${NC}"
  ui_print "${RED}└────────────────────────────────────────────────────────────┘${NC}"
  ui_print ""
}

# Print iteration status (compact)
print_iteration() {
  local step="$1"
  local iteration="$2"
  local max_iteration="$3"
  local total="$4"

  ui_print "${GRAY}[${NC}${CYAN}$step${NC}${GRAY}]${NC} ${ICON_LOOP} Iteration ${BOLD}$iteration${NC}/$max_iteration ${GRAY}(total: $total)${NC}"
}

# Print advancing message
print_advancing() {
  local from="$1"
  local to="$2"
  local to_name="$3"

  ui_print "${BLUE}${ICON_ARROW}${NC} Advancing: ${GRAY}$from${NC} ${ICON_ARROW} ${GREEN}$to${NC} - $to_name"
}

# Print phase advancing message
print_phase_advancing() {
  local from_phase="$1"
  local to_phase="$2"
  local to_phase_name="$3"

  ui_print ""
  ui_print "${MAGENTA}${BOLD}${ICON_ARROW}${ICON_ARROW}${NC} ${WHITE}Phase Transition:${NC} ${GRAY}$from_phase${NC} ${ICON_ARROW} ${MAGENTA}$to_phase${NC} - $to_phase_name"
  ui_print ""
}

# Print warning
print_warning() {
  local message="$1"
  ui_print "${YELLOW}${BOLD}⚠${NC}  ${YELLOW}$message${NC}"
}

# Print error
print_error() {
  local message="$1"
  ui_print "${RED}${BOLD}${ICON_CROSS}${NC}  ${RED}$message${NC}"
}

# Print info
print_info() {
  local message="$1"
  ui_print "${BLUE}${BOLD}ℹ${NC}  ${WHITE}$message${NC}"
}

# Print success
print_success() {
  local message="$1"
  ui_print "${GREEN}${BOLD}${ICON_CHECK}${NC}  ${GREEN}$message${NC}"
}

# Progress bar
print_progress_bar() {
  local current="$1"
  local total="$2"
  local width="${3:-40}"
  local percent=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))

  printf "${WHITE}[${NC}" >&2
  printf "${GREEN}%*s${NC}" $filled '' | tr ' ' '█' >&2
  printf "${GRAY}%*s${NC}" $empty '' | tr ' ' '░' >&2
  printf "${WHITE}]${NC} ${BOLD}%3d%%${NC}" $percent >&2
}
