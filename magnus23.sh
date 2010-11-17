#!/bin/bash

source ./configuration.sh

mkdir -p "$EVENTS"

function dream
{
   sleep $(( RANDOM % 120 ))
   d="$(shuf -n1 $BASE_DIR/dreams.txt)"
   print "$d"
}

function award
{
   user="${1%%[ :]*}"
   tmp="${1#*[ :]}"
   awardid="${tmp%%[ :]*}"
   award="${tmp#*[ :]}"
   [[ -z "$awardid" ]] && {
      print "F'thagn! !award user id [name]"
      return
   }
   votes=$BASE_DIR/awards/$awardid
   [[ -d $votes ]] ||
      mkdir -p $votes
   [[ -n "$award" ]] && [[ -f $votes/award.txt ]] ||
         echo "$award" >"$votes/award.txt"
   [[ -f "$votes/$user" ]] && 
      (echo "$2"; cat <"$votes/$user" 2>/dev/null) | sort | uniq >"$votes/$user" || 
      echo "$2" >"$votes/$user"
   
   print "$2 unlocks achievement: ($awardid) \"$award\" for $user"
}

function listawards
{
   awards=$BASE_DIR/awards
   user="${1%%[ :]*}"
   [[ -z "$user" ]] && {
      print "F'thagn!!! !listawards user"
      return
   }
   result=""
   for awardid in $(echo $awards/*/); do
      awardid=${awardid%/}
      award=$(cat $awardid/award.txt)
      rank=$(wc -l "$awardid/$user" 2>/dev/null | cut -d' ' -f1)
      [[ "$rank" -gt 1 ]] && {
         result="$result, ${awardid##*/}[$rank]"
      } 
   done
   [[ -n "$result" ]] &&
      print "$user ${result##, }"
}

function listheroes
{
   awardid="${1%%[ :]*}"
   [[ -z "$awardid" ]] && {
      print "F'thagn!!! !listheros id"
      return
   }
   votes=$BASE_DIR/awards/$awardid
   award=$(cat $votes/award.txt)
   result=""
   for user in $(echo $votes/*); do
      user=${user##*/}
      [[ "$user" == 'award.txt' ]] && continue
      rank=$(wc -l "$votes/$user" | cut -d' ' -f1)
      [[ "$rank" -gt 1 ]] && {
         result="$result, $user[$rank]"
      }
   done
   [[ -z "$result" ]] &&
      print "locked: (${awardid}) $award " || 
      print "(${awardid}) $award ${result##, }"
}

function tell
{
   user="${1%%[ :]*}"
   msg="${1#*[ :]}"
   echo "$user: $2 says \"$msg\""
   echo "$user: $2 says \"$msg\"" >>"$BASE_DIR/tell/$user" &&
      print "ACK" || print "NACK"
}

function dotell
{
   cat "$BASE_DIR/tell/$1" | while read line; do
      print "$line" 
   done && rm "$BASE_DIR/tell/$1" 
}

function auth
{
   grep -qs "^$1$" $BASE_DIR/auth || { 
      print "NOOOOOOOOO!!1!!tizenegy!!!"
      return 1
   }
}

function post_event
{
  auth "$2" || return
  local text
  text="$(grep -q 8859 <<<"$(file - <<<"$1")" && \
          iconv -f latin1 -t utf-8 <<<"$1" || \
          echo "$1")"
          
  echo "Posting event: $text (sent by $2)"

  ./grindr/feedr <"$CALENDAR_LOGIN"
  (./hspbp-tiki-add-event "$text" "$2" | ./grindr/feedr) &&
     print "ACK" || print "F'taghn! \"yyyy-mm-dd hh:mm+h <title>|<blabla>"
}

function post_tweet
{
  auth "$2" || return
  local text
  text="$(grep -q 8859 <<<"$(file - <<<"$1")" && \
          iconv -f latin1 -t utf-8 <<<"$1" || \
          echo "$1")"
          
  echo "Tweeting: $text (sent by $2)"
  
  ttytter -silent -status="$text" && \
      print "Tweet SUCCESS!" || print "Tweet failed... :("
}

function get_tweets
{
  while ! curl --silent --connect-timeout 15 \
    'http://search.twitter.com/search.atom?q=hspbp&show_user=true&rpp=50' | \
    perl -0ne 'use HTML::Entities; print $1.";".decode_entities($2)."\n"
               while /<entry>.*?<id>.*?(\d*?)<\/id>.*?<title>(.*?)<\/title>/sg' | \
    iconv -f latin1 -t utf-8 | sort -n | tail -n 20
  do
    debug "Getting tweets failed, stalling for 60 seconds"
    sleep 60
  done
}

function next_event_id
{ 
  local id
  
  for ((id=1; id <= 20; id++))
  do
    if [ ! -f "$EVENTS/$id" ]
    then
      echo $id
      return 0
    fi
  done
  
  return 1
}

function msg_nick
{
  perl -ne 'print $1 if /^\d{4}-\d{2}-\d{2} \d{2}:\d{2} <(.*?)>/' <<<"$MSG"
}

function msg_text
{
  perl -ne 'print $1 if /^\d{4}-\d{2}-\d{2} \d{2}:\d{2} <.*?> (.*)/' <<<"$MSG"
}

function validate_time
{
  egrep -q '^([0-9]+(d|h|m|s)? ?)+$' <<<"$*"
}

function translate_time
{
  if egrep -q '^([0-9]+[dhm]?)+$' <<<"$1"
  then
    # this is a countdown time
    echo "$*" | perl -ne 's/d/*86400\+/g;
                          s/h/*3600\+/g;
                          s/m/*60\+/g;
                          s/s//g;
                          s/\+$//;
                          print time + eval'
  else
    # this is a timestamp
    date -d "$1" +%s
  fi
}

function print_help
{
  print 'My available commands are: !tweet, !addquote, !lastquote, !randomquote, !addevent, !listevents, !delevent, !postevent, !tell, !award, !listawards, !listheroes'
}

function addquote
{
  echo "$(date +%Y-%m-%d\ %H:%M:%S) $1" >> "$QUOTES"
  print "New quote accepted: $1"
  echo "New quote accepted: $1"
}

function addevent
{
  time="$(perl -lne \
     'print $1 if /^((\d{4}-\d{2}-\d{2} )?(\d{2}:\d{2}(:\d{2})?)?|(\d+([dhm]?))+)/' <<<"$1")"
  if [ -n "$time" ]
  then
    time="$(translate_time "$time")"
    id=$(next_event_id) && \
      { echo "$time" > "$EVENTS/$id"
         echo "$(perl -pe 's/^((\d{4}-\d{2}-\d{2} )?(\d{2}:\d{2}(:\d{2})?)?|(\d+([dhm]?))+) ?//' \
          <<<"$1")" >> "$EVENTS/$id"
        print "Event $id successfully added. ($(timesplit $(( $time - $(date +%s) ))))"
      } || print "No more events can be added. Remove one using !delevent or let one expire."
  else
    print "I don't understand the time."
  fi
}

function delevent
{
  id="$1"
  [ -f "$EVENTS/$id" ] && \
  {
    rm "$EVENTS/$id"
    print "Event $id successfully removed."
  } || print "No such event."
}

function listevents
{
  if [ $(ls "$EVENTS/" | grep -c '') -gt 0 ]
  then
    for event in $(grep -H '' "$EVENTS"/* | sed '0~2d' | sort -t : -k 2 -n | cut -d: -f 1)
    do
      print "Event ${event##*/}: $(sed -n 2p "$event") -"\
" $(timesplit $(( $(sed -n 1p "$event") - $(date +%s) )))"
    done
  else
    print "No running event countdowns."
  fi
}

function handle_commands
{
  (tail --pid=$$ -fn0 "$IRC_CONNECTIONS/$IRC_HOST/$IRC_CHAN/out" |sed -u 's/[`$]//g') |  while read MSG
  do

    case "${MSG##[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-2][0-9]:[0-5][0-9] -[\!]- }" in
       *changed\ mode\/$IRC_CHAN*\+o*${IRC_NICK})
          print "i will spare your pathetic soul, for now."; continue;;
       jimm-erlang-bot\(\~jimm-erla@vsza.hu\)\ has\ joined\ $IRC_CHAN)
          print "ohai my dear food^Wfriend"; print "/mode $IRC_CHAN +o jimm-erlang-bot"; continue;;
       stf\(\~stf@92.43.201.132\)\ has\ joined\ $IRC_CHAN)
          print "come slave"; print "/mode $IRC_CHAN +o stf";continue;;
    esac

    message_text="$(msg_text)"
    [[ -f "$BASE_DIR/tell/$(msg_nick)" ]] && dotell "$(msg_nick)"

    case "$message_text" in
       !help)
          print_help ;;
       !addquote\ *)
          addquote "${message_text#\!addquote }" ;;
       !lastquote)
          print "Last quote: $(tail -n1 "$QUOTES")" ;;
       !quote|!randomquote)
          print "$(shuf -n1 "$QUOTES")" ;;
       !addevent\ *)
          addevent "${message_text#\!addevent }" ;;
       !delevent\ *)
          delevent "$(cut -d' ' -f2 <<<"$message_text")" ;;
       !listevents)
          listevents ;;
       !postevent\ *)
          post_event "${message_text#\!postevent }" "$(msg_nick)" ;;
       !tweet\ *)
          post_tweet "${message_text#\!tweet }" "$(msg_nick)" ;;
       !twitter\ *)
          post_tweet "${message_text#\!twitter }" "$(msg_nick)" ;;
       !tell\ *)
          tell "${message_text#\!tell }" "$(msg_nick)" ;;
       !award\ *)
          award "${message_text#\!award }" "$(msg_nick)" ;;
       !listawards\ *)
          listawards "${message_text#\!listawards }" "$(msg_nick)" ;;
       !listheroes\ *)
          listheroes "${message_text#\!listheroes }" "$(msg_nick)" ;;
    esac 

    [[ $(msg_nick) == "$IRC_NICK" ]] ||
       case "$message_text" in
         arise\ ${IRC_NICK}*)
            print "I will devour your disgusting soul, mortal!";;
         *hail\ ${IRC_NICK}*)
            print "Yes! Hail me! while you still can, until my tentacles will tear your soul apart!";;
         *fuck\ you\ ${IRC_NICK}*) print "/kick $(msg_nick)"; print "DON'T fuck with the mighty one!!!1!!!" ;;
         *imadom\ ${IRC_NICK}*) print "na meg egy hivo. mondjuk attol meg nem leszel finomabb...";;
         *${IRC_NICK}\ \<3*) print "tentacleporn!";;
         *fail\ ${IRC_NICK}) print "$(msg_nick), te hitetlen. te leszel a reggelim";;
         *${IRC_NICK}*) dream& ;;
       esac
  done
}

function handle_events
{
  local event
  while syncSleep
  do
    for event in "$EVENTS"/*
    do
      [ -f "$event" ] && \
      {
        remaining="$[ $(head -n1 "$event") - $(date +%s) ]"
        [ $remaining -le 0 ] && \
        {
          print "NOW: $(tail -n1 "$event")"
          rm "$event"
          break
        }
        lastinterval=1000000000
        for interval in 86400 21600 3600 900 300 60 15 5 1
        do
          if [ $remaining -lt $lastinterval ] &&
             [ $remaining -ge $interval ] &&
             [ $(( $remaining % $interval )) == 0 ]
          then
            [ $interval -ge 60 ] && \
              print "Event $(basename $event): $(timesplit "$remaining")"\
" until $(tail -n1 "$event")" || \
              print "$(timesplit "$remaining")"
            break
          fi
          lastinterval="$interval"
        done
      }
    done
  done
}

function handle_tweets
{
  get_tweets > tweets
  cp tweets tweets.old
  
  while true
  do
    diff tweets tweets.old | perl -lne \
      'print "$2: $3 - http://www.twitter.com/$2/statuses/$1" if /^< (.\d+);(.\w+): ?(.*)/' | \
    while read tweet
    do
      grep -q "hspbp" <<<"$tweet" && print "$tweet"
      echo "$tweet" >> log.txt
    done
    cp tweets tweets.old
    sleep 60
    get_tweets > tweets.new
    [[ -s tweets.new ]] && mv tweets.new tweets
  done
}

function enqueue
{
  perl -e "use Tie::File; tie @a, \"Tie::File\", \"$1\"; push @a, \"\$ARGV[0]\"" "$2"
} 

function dequeue
{ 
  perl -le "use Tie::File; tie @a, \"Tie::File\", \"$1\"; print shift @a"
}

function print
{
  enqueue "$MESSAGES" "$1"
  echo "$1"
}

function handle_messages
{
  while syncSleep
  do
    MSG="$(dequeue "$MESSAGES")"
    if [ -n "$MSG" ]; then
      echo "$MSG" > "$IRC_CONNECTIONS/$IRC_HOST/$IRC_CHAN/in"
    fi
  done
} 

function syncSleep
{
  perl -e '
    use Time::HiRes;
    $time = Time::HiRes::gettimeofday();
    select(undef,undef,undef, '"${1:-0}"' + 1 - ($time - int($time)));'
}

function timesplit
{
  local seconds
  local days
  local hours
  local minutes
  
  seconds=$(echo $1 | cut -d. -f 1)
  [ -z "$seconds" ] && seconds=0
  days=$[ $seconds / 86400 ]
  seconds=$[ $seconds % 86400 ]

  hours=$[ $seconds / 3600 ]
  seconds=$[ $seconds % 3600 ]
  minutes=$[ $seconds / 60 ]
  seconds=$[ $seconds % 60 ]
  
  [ $days -gt 0 ] && echo -n "$days days" && [ $seconds -gt 0 ] && echo -n ", "
  [ $hours -gt 0 ] && echo -n "$hours hours" && [ $seconds -gt 0 ] && echo -n ", "
  [ $minutes -gt 0 ] && echo -n "$minutes minutes" && [ $seconds -gt 0 ] && echo -n ", "
  [ $seconds -gt 0 ] && echo "$seconds seconds"
}

handle_commands &
cmddesc=$!
handle_tweets &
twtdesc=$!
handle_events &
evdesc=$!
handle_messages &
msgdesc=$!

trap "kill $cmddesc $twtdesc $evdesc $msgdesc; exit" 2

wait
