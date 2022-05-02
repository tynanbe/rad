#!/usr/bin/env bash

# Hello, this is Apple Kid. I just wanted to let you know that I finished a
# pretty unique invention. I'm not sure if it will help you or not... It's
# called "Zombie Paper", and it can be used to trap zombies. It works kind of
# like fly paper... All you need to do is to place the paper on the floor of a
# tent or something... You've seen at least one tent around, right?.... and then
# the zombies get stuck to the paper when they move around inside the tent. You
# can catch a lot of zombies this way... In fact, I bet you could get rid of all
# the zombies that are terrorizing the area with this paper!

# Start the program in the background
exec "$@" &
pid1=$!

# Silence warnings from here on
exec >/dev/null 2>&1

# Read from stdin in the background and
# kill running program when stdin closes
exec 0<&0 $(
  while read; do :; done
  kill -KILL $pid1
) &
pid2=$!

# Clean up
wait $pid1
ret=$?
kill -KILL $pid2
exit $ret
