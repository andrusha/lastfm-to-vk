def is_valid_session?(session)
  session[:token]      &&
  session[:expires_at] &&
  Time.now.getutc.to_i < session[:expires_at]
end

def has_file?(params)
  params[:file]            &&
  params[:file][:tempfile] &&
  params[:file][:filename]
end

def parse_tsv(file)
  # starting from the second line, split by tabs and keep
  # only first two entities (artist, track)
  file.readlines[1..-1].map! { |l| l.downcase.split("\t")[0..1].reverse! }
end
