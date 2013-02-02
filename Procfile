web: bundle exec unicorn -p $PORT -c ./unicorn.rb -E $RACK_ENV
worker: env TERM_CHILD=1 COUNT=3 QUEUE=* bundle exec rake resque:work
