web: bundle exec unicorn -p $PORT -c ./unicorn.rb -E $RACK_ENV
worker: env TERM_CHILD=1 QUEUE=* bundle exec rake resque:work
