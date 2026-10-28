# frozen_string_literal: true

# hydra-derivatives waits on ffmpeg and LibreOffice forever by default; a hung
# one then holds its worker slot. Our longest real encodes take about 2.5 hours.
[
  Hydra::Derivatives::Processors::Video::Processor,
  Hydra::Derivatives::Processors::Audio,
  Hydra::Derivatives::Processors::Document
].each { |processor| processor.timeout = 4.hours.to_i }
