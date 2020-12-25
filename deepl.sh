#!/bin/bash

# setup #######################################################################
#set -o errexit -o pipefail -o noclobber -o nounset
VERSION="1.20"
PATH="$PATH:/usr/local/bin/"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
LANGUAGE=${DEEPL_TARGET:-ZH}
PARSER="jq"
if ! type "$PARSER" >/dev/null 2>&1; then
  PARSER="${DIR}/jq-dist"
fi
###############################################################################

# helper functions ############################################################
function printJson() {
  echo '{"items": [{"uid": null,"arg": "'"$1"'","valid": "yes","autocomplete": "autocomplete","title": "'"$1"'"}]}'
}
###############################################################################

# parameters ##################################################################
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case "$key" in
  -l | --lang)
    LANGUAGE="$2"
    shift # past argument
    shift # past value
    ;;
  *) # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift              # past argument
    ;;
  esac
done
set -- "${POSITIONAL[@]:-}" # restore positional parameters
###############################################################################

# help ########################################################################
if [ -z "$1" ]; then
  echo "Home made DeepL CLI (${VERSION}; https://github.com/AlexanderWillner/deepl-alfred-workflow2)"
  echo ""
  echo "SYNTAX : $0 [-l language] <query>" >&2
  echo "Example: $0 -l DE \"This is just an example.\""
  echo ""
  exit 1
fi
###############################################################################

# process query ###############################################################
query="$(echo "$1" | iconv -f utf-8-mac -t utf-8)"

if [[ $query != *. ]]; then
  printJson "End query with a dot"
  exit 1
fi
###############################################################################

# prepare query ###############################################################
# shellcheck disable=SC2001
query="$(echo "$query" | sed 's/.$//')"
# shellcheck disable=SC2001
query="$(echo "$query" | sed 's/\"/\\\"/g')"

data='{"jsonrpc":"2.0","method": "LMT_handle_jobs","params":{"jobs":[{"kind":"default","raw_en_sentence":"'"$query"'","preferred_num_beams":4,"raw_en_context_before":[],"raw_en_context_after":[],"quality":"fast"}],"lang":{"user_preferred_langs":["ZH","EN","JA"],"source_lang_user_selected":"auto","target_lang":"'"${LANGUAGE:-ZH}"'"},"priority":-1,"timestamp":1557063997314},"id":79120002}'
HEADER=(
  --compressed
  -H 'authority: www2.deepl.com'
  -H 'Origin: https://www.deepl.com'
  -H 'Referer: https://www.deepl.com/translator'
  -H 'Accept: */*'
  -H 'Content-Type: application/json'
  -H 'Accept-Language: en-us'
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1 Safari/605.1.15'
  -H 'Cookie: dl_session=f498f467-d62e-aaa9-3b04-5059f0eb4778; dl_logoutReason=%7B%22loggedOutReason%22%3A%22USER_REQUEST%22%2C%22loggedOutReasonText%22%3A%22%5Cu4f60%5Cu5df2%5Cu7ecf%5Cu9000%5Cu51fa%5Cu767b%5Cu5f55%5Cu3002%22%7D; privacySettings=%7B%22v%22%3A%221%22%2C%22t%22%3A1607990400%2C%22m%22%3A%22LAX%22%2C%22consent%22%3A%5B%22NECESSARY%22%2C%22PERFORMANCE%22%2C%22COMFORT%22%5D%7D;'
)
###############################################################################

# query #######################################################################
result=$(curl -s 'https://www2.deepl.com/jsonrpc' \
  "${HEADER[@]}" \
  --data-binary $"$data")

if [[ $result == *'"error":{"code":'* ]]; then
  message=$(echo "$result" | "$PARSER" -r '.["error"]|.message')
  printJson "Error: $message"
else
  echo "$result" | "$PARSER" -r '{items: [.result.translations[0].beams[] | {uid: null, arg:.postprocessed_sentence, valid: "yes", autocomplete: "autocomplete",title: .postprocessed_sentence}]}'
fi
###############################################################################
