#!/bin/bash

source ./configuration.sh

mkdir -p "$EVENTS"

function dream
{
   sleep $(( RANDOM % 120 ))
   d="$(shuf -n1 $BASE_DIR/dreams.txt)"
   print "$d"
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
  print 'My available commands are: !tweet, !addquote, !lastquote, !randomquote, !addevent, !listevents, !delevent, !postevent, !tell'
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
  tail --pid=$$ -fn0 "$IRC_CONNECTIONS/$IRC_HOST/$IRC_CHAN/out" | while read MSG
  do
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
    esac 

    case "$message_text" in
      *${IRC_NICK}*)
         dream& ;;
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
"until $(tail -n1 "$event")" || \
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
    get_tweets > tweets
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
handle_tweets &
handle_events &
handle_messages &

wait

