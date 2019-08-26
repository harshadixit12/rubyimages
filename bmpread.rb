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
    if @bits_per_pixel <= 8
      @palette = []
      (1..@numcolors).each do |i|
        puts i.to_s
        b = @raw_data.sysread(1).unpack('C')[0]
        g = @raw_data.sysread(1).unpack('C')[0]
        r = @raw_data.sysread(1).unpack('C')[0]
        temp = @raw_data.sysread(1).unpack('C')
        @palette[i - 1] = [r, g, b]
      end
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
    puts "Used colors: #{@colors_used}"
    puts "Number of important colors: #{@num_of_imp_colors} (0 if all are important)"
  end

  def read_to_array
    @raw_data.sysseek(@offset)
    a = Array.new(@height)
    if @bits_per_pixel <= 8
      (1..@height).each do |i|
        row_array = Array.new(@width)
        (1..@width).each do |j|
          pixel_value = @raw_data.sysread(1).unpack('C')[0]
          row_array[j - 1] = @palette[pixel_value]
        end
        @raw_data.sysread((@width * 3) % 4) # zeros are appended to rows of pixels if the image width is not a multiple of 4, this ignores them.
        a[i - 1] = row_array
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
        a[i - 1] = row_array
      end
      puts "Location of pointer after reading: #{@raw_data.pos}"
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

x = Image.new('../pepper.bmp') #enter local path
x.describe
# x.printcolors()
pixels = x.read_to_array

# prints the array
(1..x.height).each do |_i|
  # puts "#{i}: ****" #Row number
  (1..x.width).each do |j|
    # print pixels[i-1][j-1] #[R G B]
  end
  # puts "****"
end
