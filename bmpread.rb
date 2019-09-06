# frozen_string_literal: true

# require 'nmatrix'
class Image
  def initialize(path)
    file_descriptor = IO.sysopen(path)
    @raw_data = IO.new(file_descriptor)
    @signature = @raw_data.sysread(2)
    @size = @raw_data.sysread(4).unpack('L')[0] # Because little endian format
    @raw_data.sysseek(10)
    @offset = @raw_data.sysread(4).unpack('L')[0]
    @info_header_size = @raw_data.sysread(4).unpack('L')[0]
    @width = @raw_data.sysread(4).unpack('L')[0]
    @height = @raw_data.sysread(4).unpack('L')[0]
    @planes = @raw_data.sysread(2).unpack('S')[0]
    @bits_per_pixel = @raw_data.sysread(2).unpack('S')[0]
    @numcolors = 2**@bits_per_pixel
    @compression = @raw_data.sysread(4).unpack('N')[0]
    @compressed_size = @raw_data.sysread(4).unpack('L')[0]
    @x_pixels_per_m = @raw_data.sysread(4).unpack('L')[0]
    @y_pixels_per_m = @raw_data.sysread(4).unpack('L')[0]
    @colors_used = @raw_data.sysread(4).unpack('L')[0]
    @num_of_imp_colors = @raw_data.sysread(4).unpack('L')[0]
    read_to_palette if @bits_per_pixel <= 8
  end

  def read_to_palette
    @palette = []
    (1..@numcolors).each do |i|
      b = @raw_data.sysread(1).unpack('C')[0]
      g = @raw_data.sysread(1).unpack('C')[0]
      r = @raw_data.sysread(1).unpack('C')[0]
      temp = @raw_data.sysread(1).unpack('C')
      @palette[i - 1] = [r, g, b]
      puts "#{r},#{g},#{b}"
    end
  end

  def describe
    puts 'Header Data'
    puts "Signature: #{@signature}"
    puts "Size: #{@size}"
    puts "Offset: #{@offset}"
    puts 'InfoHeader Data'
    puts "Infoheader size: #{@info_header_size}"
    puts "Width: #{@width}"
    puts "Height: #{@height}"
    puts "Planes: #{@planes}"
    puts "Bits per pixel = #{@bits_per_pixel}"
    puts "Compression: #{@compression}"
    if @compression.zero?
      puts 'Compression: None'
    elsif @compression == 1
      puts 'Compression: BI_RLE8 8 bit encoding'
    elsif @compression == 2
      puts 'Compression: BI_RLE4 4 bit encoding'
    end
    puts "Compressed image size: #{@compressed_size}"
    puts "Pixel density on x-axis (per m): #{@x_pixels_per_m}"
    puts "Pixel density on y-axis (per m): #{@y_pixels_per_m}"
    puts "Used colors (in color palette): #{@colors_used}"
    puts "Number of important colors: #{@num_of_imp_colors} (0 if all are important)"
  end

  def read_to_array
    @raw_data.sysseek(@offset)
    a = Array.new(@height)
    if @compression.zero?
      if @bits_per_pixel <= 8
        a = read_from_palette
      elsif @bits_per_pixel > 8
        a = read_from_pixel_array
        # puts "Location of pointer after reading: #{@raw_data.pos}"
      end
    end
    a
  end

  def read_from_palette
    a = Array.new(@height)
    if @bits_per_pixel == 1
      row_length = ((@width / 32).floor * 32 + 32) / 8
      (1..@height).each do |i|
        colors = []
        row_length_data = ''
        (1..row_length).each do
          row_length_data += @raw_data.sysread(1).unpack('C')[0].to_s
        end
        (1..@width).each do |j|
          colors[j - 1] = @palette[row_length_data[j].to_i]
        end
        a[@height - i] = colors
      end
    elsif @bits_per_pixel == 2
      (1..@height).each do |i|
        row_array = []
        row_length = ((@width / 32).floor * 32 + 32) / 8
        count = 0
        (1..row_length).each do |_j|
          break if count > @width

          byteval = @raw_data.sysread(1).unpack('C')[0]
          fourth = byteval & 3
          byteval >> 2
          third = byteval & 3
          byteval >> 2
          second = byteval & 3
          byteval >> 2
          first = byteval
          row_array.push(@palette[first])
          count += 1
          break if count >= @width

          row_array.push(@palette[second])
          count += 1
          break if count >= @width

          row_array.push(@palette[third])
          count += 1
          break if count >= @width

          row_array.push(@palette[fourth])
          count += 1
          break if count >= @width
        end
        a[@height - i] = row_array
      end
    elsif @bits_per_pixel == 4
      (1..@height).each do |i|
        row_array = []
        row_length = ((@width * 4 / 32).floor * 32 + 32) / 8
        count = 0
        (1..row_length).each do |_j|
          break if count >= @width

          byteval = @raw_data.sysread(1).unpack('C')[0]
          second = byteval & 15
          byteval >> 4
          first = byteval
          row_array.push(@palette[first])
          count += 1
          break if count >= @width

          row_array.push(@palette[second])
          count += 1
        end
        a[@height - i] = row_array
      end
    elsif @bits_per_pixel == 8
      (1..@height).each do |i|
        row_array = Array.new(@width)
        (1..@width).each do |j|
          row_array[j - 1] = @palette[@raw_data.sysread(1).unpack('C')[0]]
        end
        @raw_data.sysread((@width * 3) % 4) # zeros are appended to rows of pixels if the image width is not a multiple of 4, this ignores them.
        a[@height - i] = row_array
      end
    end
    a
  end

  def read_from_pixel_array
    a = Array.new(@height)
    if @bits_per_pixel == 16 # works for rgb555 format, not rgb565
      (1..@height).each do |i|
        row_array = Array.new(@width)
        (1..@width).each do |j|
          bindata = @raw_data.sysread(2).unpack('n')[0]
          r = bindata & 0b11111
          bindata >> 5
          g = bindata & 0b11111
          bindata >> 5
          b = bindata & 0b11111
          bindata >> 5
          row_array[j - 1] = [r, g, b]
        end
        @raw_data.sysread((@width * 3) % 4) # zeros are appended to rows of pixels if the image width is not a multiple of 4, this ignores them.
        a[@height - i] = row_array
      end

    elsif @bits_per_pixel == 24
      (1..@height).each do |i|
        row_array = Array.new(@width)
        (1..@width).each do |j|
          b = @raw_data.sysread(1).unpack('C')[0]
          g = @raw_data.sysread(1).unpack('C')[0]
          r = @raw_data.sysread(1).unpack('C')[0]
          row_array[j - 1] = [r, g, b]
        end
        @raw_data.sysread((@width * 3) % 4) # zeros are appended to rows of pixels if the image width is not a multiple of 4, this ignores them.
        a[@height - i] = row_array
      end
    elsif @bits_per_pixel == 32 # not tested with an image yet, maybe order of colors is wrong
      (1..@height).each do |i|
        row_array = Array.new(@width)
        (1..@width).each do |j|
          b = @raw_data.sysread(1).unpack('C')[0]
          g = @raw_data.sysread(1).unpack('C')[0]
          r = @raw_data.sysread(1).unpack('C')[0]
          alpha = @raw_data.sysread(1).unpack('C')[0]
          row_array[j - 1] = [r, g, b, alpha] # should be changed based on requirement
        end
        @raw_data.sysread((@width * 3) % 4) # zeros are appended to rows of pixels if the image width is not a multiple of 4, this ignores them.
        a[@height - i] = row_array
      end
    end
    a
  end
  # will do once the bug is fixed

  def read_to_nmatrix
    result = [] # NMatrix.new([3, 3],dtype: :int64)
    result
  end

  # getters
  attr_reader :width

  attr_reader :height
end

x = Image.new('testimages/rgb16.bmp') # enter local path
x.describe
# x.printcolors()

pixels = x.read_to_array

# prints the array
(1..x.height).each do |i|
  puts "#{i}: ****" # Row number
  (1..x.width).each do |j|
    print pixels[i - 1][j - 1] # [R G B]
  end
  puts '****'
end
puts pixels.length
puts pixels[0].length
