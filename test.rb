# A down-and-dirty scraper to grab as many Ikea products as possible
# This was used to create a 2500 product seed file for our group project

# Each .csv of products will get saved to ./products. I've left A.csv there
# to show you what the output looks like.  When importing this to our app,
# we found variations in several products that required hand-editing to
# allow their import.  YMMV.

# Obviously, this could use a lot of cleaning up!

require 'nokogiri'
require 'open-uri'
require 'pry'
require 'csv'

# Ikea's "All Products A-Z" page has a link to each letter, numbered 0-25
# The #scraper method expects an array of numbers in that range and will scrape
# each corresponding letter
def scraper(range)
  range.each do |index|
    products = []
    counter = 0
    letter = (index + 65).chr

    # Open the specified product page, throw it into a Nokogiri object
    puts "Opening: http://www.ikea.com/us/en/catalog/productsaz/#{index}"
    az_page = Nokogiri::HTML(open("http://www.ikea.com/us/en/catalog/productsaz/#{index}"))
    # pull out the product links
    product_links = az_page.css('span.productsAzLink a')

    # This blacklist was built over several runs.  Several products will crash
    # the scraper - they're 404's, redirects, etc.
    product_links.each do |product|
      blacklist = [
        "/us/en/catalog/products/S59932146/",
        "/us/en/catalog/products/S99014376/",
        "/us/en/catalog/products/60285335/",
        "/us/en/catalog/products/40173777/",
        "/us/en/catalog/products/70288183/"
      ]

      # Grab the URL of this product
      url_fragment = product.attribute('href').text

      puts "Scraping '#{url_fragment}'"
      # only go after what we think are good URLs
      unless !url_fragment.include?("product") || blacklist.include?(url_fragment)
        products << scrape_product_data(url_fragment)
        puts "Stashing #{products.last.title} in array"
      end
    end

    # Now that we have all the product info we're going to get from this page,
    # save it all out to a csv
    products.each do |the_product|
      CSV.open("./products/#{letter}.csv", "ab") do |csv|
          csv << [
            the_product.url,
            the_product.title,
            the_product.subtitle,
            the_product.picture_url,
            the_product.price,
            the_product.category,
            the_product.article_number
          ]
          counter += 1
      end
    end

    puts "#{letter}.csv saved with #{counter} lines"
  end
end

def scrape_product_data(url_fragment)
  url = "http://www.ikea.com#{url_fragment}"
  parsed_page = Nokogiri::HTML(open(url))

  # stuff all our data into an IkeaProduct object
  product = IkeaProduct.new

  # use #tr to strip out possible problematic characters
  product.url = url
  product.title = parsed_page.xpath('//div[@id="name"]').text.tr("$\"\t\r\n", "").strip
  product.subtitle = parsed_page.xpath('//div[@id="type"]').text.tr("$\"\t\r\n", "").strip
  product.picture_url = "http://www.ikea.com#{parsed_page.xpath('//img[@id="productImg"]//@src').text}"
  product.price = parsed_page.xpath('//head//meta[@name="price"]//@content').text.tr("$\t\r\n", "").strip
  product.article_number = parsed_page.xpath('//div[@id="itemNumber"]').text.tr("$.\t\s\r\n", "").strip

  scraped_cats = parsed_page.css('ul[@id=breadCrumbs] li a')
  if !scraped_cats.nil?
    product.category = scraped_cats[1].text.tr("$\"\t\r\n", "").strip
  else
    product.category = []
  end
  product
end


class IkeaProduct
  attr_accessor :url, :title, :subtitle, :picture_url, :price, :category, :article_number

  def initialize
    @category = []
  end

  def to_s
    %Q(
      URL: #{url}
      Article Number: #{article_number}
      Title: #{title}
      Subtitle: #{subtitle}
      Picture URL: #{picture_url}
      Price: #{price}
      Category: #{category}
    )
  end
end

# runs the scraper
range = (0..25).to_a
scraper(range)
