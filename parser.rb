require 'open-uri'
require 'nokogiri'
require 'csv'

class Parser
  def initialize url, file
    @host = url.gsub(/https?:\/\/[a-z\.]+/).first
    @category = Category.new(url)
    @exporter = Exporter.new(file)
  end

  def perform
    1.upto @category.pages do |page|
      perform_results page
    end
  end

  private
  def perform_results page
    doc = Loader.get_page(@category.url, @category.per_page, page)
    result_links = doc.css('.families-list li').xpath('a/@href')
    result_links.each_with_index do |link, i|
      perform_products link
      puts "product #{i+1}/#{result_links.count} #{link} on page #{page}/#{@category.pages} saved"
    end
  end

  def perform_products link
    url = URI.parse("#{@host}#{link}")
    doc = Nokogiri::HTML(open(url))
    title = doc.css('#product_family_heading').first.content
    products = doc.css('#product_listing li.product')
    products.each do |item|
      product = Product.new(item, title)
      @exporter.write product.data
    end
  end
end

class Category
  attr_accessor :pages, :url, :per_page

  def initialize url, per_page: 300
    @per_page = per_page
    @url = url
    @pages = pages_number
  end

  def pages_number
    prev_next_links = 2
    doc = Loader.get_page(@url, @per_page)
    doc.css('.pagination ul li').count - prev_next_links
  end
end

class Exporter
  def initialize file
    @file = CSV.open(file, "wb")
  end

  def write data
    @file << data
  end
end

class Loader
  def self.get_page(url, per_page, page = 1)
    url = URI.parse("#{url}?items_per_page=#{per_page}&page=#{page}")
    doc = open(url)
    Nokogiri::HTML(doc)
  end
end

class Product
  def initialize product, title
    @name = "#{title} - #{product.css('.title').first.content.strip}"
    @price = product.css('span[itemprop="price"]').first.content
    photo_view = product.css('.buttonthings .photo-view').first
    @image = "http:" + photo_view.attr('data-thumbnail') if photo_view
    @delivery = product.css('.stock.in-stock').first.content.strip
    @product_code = product.css('strong[itemprop="sku"]').first.content
  end

  def data
    [@name, @price, @image, @delivery, @product_code]
  end
end

url, file = ARGV[0], ARGV[1] || 'results.csv'
parser = Parser.new(url, file).perform
