# frozen_string_literal: true

# Remove once Hyku includes samvera/hyku#3487.
# hydra-derivatives waits on ffmpeg forever by default; a hung one then holds its
# worker slot. Our longest real encodes take about 2.5 hours.
[
  Hydra::Derivatives::Processors::Video::Processor,
  Hydra::Derivatives::Processors::Audio
].each { |processor| processor.timeout = 4.hours.to_i }

# An escaped filename runs the command through sh, which the timeout would kill
# instead of ffmpeg; exec makes ffmpeg the process it kills.
Hydra::Derivatives.ffmpeg_path = 'exec ffmpeg'
