#!/bin/zsh

# =============================================================================
# Cosmos SDK/Ignite 그룹 설정 및 JSON 주소 수정 스크립트
# =============================================================================

set -e

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# =============================================================================
# 선언적 매핑 정의
# =============================================================================

# 주소 사용 위치 매핑 (문서화)
show_address_usage() {
    echo ""
    log_info "주소 사용 위치:"
    echo "   ALICE: members.json/members[0].address, proposal.json/messages[0].to_address, proposal.json/proposers[0]"
    echo "   BOB: members.json/members[1].address"
    echo "   GROUP_POLICY_ADDR: proposal.json/group_policy_address, proposal.json/messages[0].from_address"
}

# 각 파일별 수정 규칙 적용
apply_address_mappings() {
    local phase="$1"
    
    case "$phase" in
        "initial")
            # Phase 1: ALICE, BOB만 설정 (그룹 생성 전)
            if [ -f "members.json" ]; then
                log_info "members.json 수정 중 (ALICE, BOB)..."
                modify_json "members.json" '.members[0].address = $alice | .members[1].address = $bob'
            else
                log_warning "members.json 파일이 없습니다"
            fi
            ;;
        "final")
            # Phase 2: 모든 주소 설정 (그룹 생성 후)
            if [ -f "proposal.json" ] && [ -n "$GROUP_POLICY_ADDR" ]; then
                log_info "proposal.json 수정 중 (모든 주소)..."
                modify_json "proposal.json" '.group_policy_address = $group_policy | .messages[0].from_address = $group_policy | .messages[0].to_address = $alice | .proposers[0] = $alice'
            else
                [ ! -f "proposal.json" ] && log_warning "proposal.json 파일이 없습니다"
                [ -z "$GROUP_POLICY_ADDR" ] && log_warning "GROUP_POLICY_ADDR이 설정되지 않았습니다"
            fi
            ;;
    esac
}

# =============================================================================
# 핵심 함수들
# =============================================================================

check_tools() {
    local daemon_name="${1:-exampled}"
    
    if ! command -v jq >/dev/null; then
        log_error "jq가 필요합니다"
        echo "설치: brew install jq (macOS) 또는 sudo apt install jq (Ubuntu)"
        exit 1
    fi
    
    if ! command -v "$daemon_name" >/dev/null; then
        log_error "$daemon_name 명령어를 찾을 수 없습니다"
        echo "Ignite로 scaffold 후 'ignite chain serve'를 실행했는지 확인하세요"
        exit 1
    fi
    
    log_success "도구 확인 완료 (daemon: $daemon_name)"
}

modify_json() {
    local file="$1"
    local filter="$2"
    
    # 백업 생성
    local backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$file" "$backup_file"
    log_info "백업 생성: $backup_file"
    
    # JSON 수정
    local temp_file=$(mktemp)
    if jq --arg alice "$ALICE" \
          --arg bob "$BOB" \
          --arg group_policy "$GROUP_POLICY_ADDR" \
          "$filter" "$file" > "$temp_file"; then
        mv "$temp_file" "$file"
        log_success "$file 수정 완료"
    else
        log_error "$file 수정 실패"
        rm -f "$temp_file"
        exit 1
    fi
}

setup_addresses() {
    local daemon_name="$1"
    
    log_info "키 정보 가져오는 중..."
    
    # Alice 주소 가져오기
    if ALICE=$($daemon_name keys show alice --address 2>/dev/null); then
        export ALICE
        echo "ALICE: $ALICE"
    else
        log_error "Alice 키를 찾을 수 없습니다"
        echo "키 생성: $daemon_name keys add alice"
        exit 1
    fi
    
    # Bob 주소 가져오기
    if BOB=$($daemon_name keys show bob --address 2>/dev/null); then
        export BOB
        echo "BOB: $BOB"
    else
        log_error "Bob 키를 찾을 수 없습니다"
        echo "키 생성: $daemon_name keys add bob"
        exit 1
    fi
}

create_group() {
    local daemon_name="$1"
    
    # 필요한 파일 확인
    if [ ! -f "members.json" ]; then
        log_error "members.json 파일이 없습니다"
        exit 1
    fi
    
    if [ ! -f "policy.json" ]; then
        log_error "policy.json 파일이 없습니다"
        exit 1
    fi
    
    log_info "그룹 생성 중..."
    echo "명령: $daemon_name tx group create-group-with-policy \"$ALICE\" \"\" \"\" members.json policy.json --gas auto --yes"
    
    if $daemon_name tx group create-group-with-policy "$ALICE" "" "" members.json policy.json --gas auto --yes; then
        log_success "그룹 생성 완료"
        sleep 3  # 블록 확정 대기
    else
        log_error "그룹 생성 실패"
        exit 1
    fi
}

get_group_policy_addr() {
    local daemon_name="$1"
    
    log_info "GROUP_POLICY_ADDR 조회 중..."
    
    # 그룹 정책 주소 가져오기
    if GROUP_POLICY_ADDR=$($daemon_name query group group-policies-by-group 1 --output json | jq -r '.group_policies[].address' 2>/dev/null); then
        if [ -n "$GROUP_POLICY_ADDR" ] && [ "$GROUP_POLICY_ADDR" != "null" ]; then
            export GROUP_POLICY_ADDR
            echo "GROUP_POLICY_ADDR: $GROUP_POLICY_ADDR"
        else
            log_error "그룹 정책 주소를 찾을 수 없습니다"
            echo "그룹이 올바르게 생성되었는지 확인하세요: $daemon_name query group groups"
            exit 1
        fi
    else
        log_error "그룹 정책 조회 실패"
        exit 1
    fi
}

save_env_file() {
    local daemon_name="$1"
    local env_file="addresses.env"
    
    cat > "$env_file" << EOF
# Generated on $(date) for daemon: $daemon_name
# Cosmos SDK Group Configuration

export ALICE="$ALICE"
export BOB="$BOB"
export GROUP_POLICY_ADDR="$GROUP_POLICY_ADDR"

# Usage commands:
# $daemon_name tx group submit-proposal proposal.json --from alice --gas auto --yes
# $daemon_name tx group vote 1 yes "" --from alice --gas auto --yes
EOF
    
    log_success "환경변수 파일 생성: $env_file"
    
    # source로 실행되지 않았을 때만 안내 메시지 출력
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ ! "${ZSH_EVAL_CONTEXT}" =~ :file$ ]]; then
        echo ""
        echo "💡 환경변수를 현재 shell에 적용하려면:"
        echo "   source $env_file"
        echo "   또는"
        echo "   source ./$(basename $0) [$daemon_name]"
    fi
}

# =============================================================================
# 사용법 및 도움말
# =============================================================================

show_usage() {
    echo "사용법: $0 [daemon_name] [--help]"
    echo ""
    echo "매개변수:"
    echo "  daemon_name     사용할 데몬 이름 (기본값: exampled)"
    echo ""
    echo "예시:"
    echo "  $0                    # exampled 사용"
    echo "  $0 myappd            # myappd 사용"
    echo "  source $0 myappd     # myappd 사용 + 환경변수 직접 적용"
    echo ""
    echo "실행 과정:"
    echo "  1. Alice/Bob 주소 자동 가져오기"
    echo "  2. members.json 주소 수정"
    echo "  3. 그룹 생성"
    echo "  4. GROUP_POLICY_ADDR 가져오기"
    echo "  5. proposal.json 주소 수정"
    echo "  6. 환경변수 파일 생성"
    echo ""
    echo "필요한 파일:"
    echo "  - members.json (그룹 멤버 정의)"
    echo "  - policy.json (그룹 정책 정의)"
    echo "  - proposal.json (제안서, 선택사항)"
}

# =============================================================================
# 메인 실행부
# =============================================================================

main() {
    local daemon_name="${1:-exampled}"
    
    # 도움말 확인
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ "$2" == "--help" ]] || [[ "$2" == "-h" ]]; then
        show_usage
        show_address_usage
        exit 0
    fi
    
    echo "========================================"
    log_info "Cosmos SDK 그룹 설정 시작 (daemon: $daemon_name)"
    echo "========================================"
    
    # 1. 도구 및 환경 확인
    check_tools "$daemon_name"
    
    # 2. 초기 주소 설정 및 members.json 수정
    setup_addresses "$daemon_name"
    apply_address_mappings "initial"
    
    # 3. 그룹 생성
    create_group "$daemon_name"
    
    # 4. GROUP_POLICY_ADDR 가져오기
    get_group_policy_addr "$daemon_name"
    
    # 5. proposal.json 수정 (있는 경우)
    apply_address_mappings "final"
    
    # 6. 환경변수 파일 생성
    save_env_file "$daemon_name"
    
    echo ""
    log_success "모든 작업 완료! 🎉"
    echo ""
    echo "다음 단계:"
    echo "source addresses.env"
    echo "$daemon_name tx group submit-proposal proposal.json --from alice --gas auto --yes"
    echo "$daemon_name tx group vote 1 \$ALICE VOTE_OPTION_YES \"\" --gas auto --yes"
}

main "$@"