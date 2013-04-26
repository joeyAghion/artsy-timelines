module Artsy
  
  class Client
    attr_accessor :xapp_token, :base_url
  
    DEFAULT_BASE_URL = "https://staging-secure.artsy.net/api/v1/"
  
    def initialize(options = {})
      self.xapp_token = options[:xapp_token] || raise("xapp_token required!")
      self.base_url = options[:base_url] || DEFAULT_BASE_URL
    end
    
    def find_artist(slug)
      response = get("artist/#{slug}")
      Artsy::Artist.new(JSON.parse(response), self)
    end
    
    def find_gene(slug)
      response = get("gene/#{slug}")
      Artsy::Gene.new(JSON.parse(response), self)
    end
    
    def find_tag(slug)
      response = get("tag/#{slug}")
      Artsy::Tag.new(JSON.parse(response), self)
    end
    
    def find_artwork(slug)
      response = get("artwork/#{slug}")
      Artsy::Artwork.new(JSON.parse(response), self)
    end
    
    def find_artworks_for_artist(slug)
      response = get("artist/#{slug}/artworks")
      JSON.parse(response).map{|json| Artsy::Artwork.new(json, self) }
    end
    
    def find_artworks_for_gene(slug)
      response = get("gene/#{slug}/artworks")
      JSON.parse(response).map{|json| Artsy::Artwork.new(json, self) }
    end
    
    def find_artists_for_gene(slug)
      response = get("gene/#{slug}/artists?size=20")
      JSON.parse(response).map{|json| Artsy::Artist.new(json, self) }
    end
    
    def find_artworks_for_tag(slug)
      response = get("tag/#{slug}/artworks")
      JSON.parse(response).map{|json| Artsy::Artwork.new(json, self) }
    end
    
    def find_related_artworks_for_artwork(slug)
      response = get("related/layer/synthetic/main/artworks?artwork%5B%5D=#{slug}")
      JSON.parse(response).map{|json| Artsy::Artwork.new(json, self) }
    end
    
    def match_url
      "#{base_url}match?visible_to_public=true"
    end
    
    def markdown
      @markdown ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, space_after_headers: true, hard_wrap: true)
    end
    
    private
    
    def get(path)
      RestClient.get(base_url + path, "X-Xapp-Token" => xapp_token)
    end
  end
  
  
  class Model
    attr_accessor :fields, :client
    
    def initialize(fields = {}, client)
      self.fields = fields
      self.client = client
    end
    
    def image_version_url(image, version, options = {})
      return nil unless options[:ignore_versions] || (image['image_versions'] && image['image_versions'].include?(version))
      image['image_url'].gsub(/:version/, version.to_s).gsub(/stagic/, 'static')
    end
    
    def valid_for_timeline?
      raise "Not yet implemented"
    end
    
    def method_missing(method, *args, &block)
      super unless fields.has_key?(method.to_s)
      fields[method.to_s]
    end
  end
  
  
  class Artist < Artsy::Model
    def birth_year
      @birth_year ||= years_list[0].presence.try(:to_i)
    end
    
    def death_year
      @death_year ||= years_list[1].presence.try(:to_i)
    end
    
    def headline
      "#{name} <em>(#{years})</em>"
    end
    
    def artworks_with_dates
      @artworks_with_dates ||= artworks.select(&:valid_for_timeline?)
    end
    
    def valid_for_timeline?
      artworks_with_dates.any?
    end
    
    def valid_for_timeline_era?
      birth_year || death_year
    end
    
    def to_timeline
      {
        timeline: {
          headline: headline,
          type: "default",
          text: client.markdown.render(blurb),
          asset: {
            media: image_version_url(fields, 'square')
          },
          date: artworks_with_dates.map{ |a| a.to_timeline_date(headline: ->(a) { a.title }) },
          era: [ to_timeline_era ]
        }
      }
    end
    
    def to_timeline_era
      {
        startDate: [birth_year].compact.join(","),
        endDate: [death_year || Time.now.year].compact.join(","),
        headline: name
      }
    end
    
    private
    
    def artworks
      @artworks ||= client.find_artworks_for_artist(id)
    end
    
    def years_list
      @years_list ||= years.scan(/\d{4}/)
    end
  end
  
  
  class Artwork < Artsy::Model
    def description
      [medium, manufacturer, dimensions_string].compact.join('<br />')
    end
    
    def description_html
      @description_html ||= client.markdown.render(description)
    end
    
    def dimensions_string
      dimensions.values.compact.join(", ")
    end
    
    def large_image
      image_version_url(default_image, 'large')
    end
    
    def thumbnail
      image_version_url(default_image, 'small')
    end
    
    def default_image
      @default_image ||= images.detect{|i| i['is_default'] }
    end
    
    def year
      @year ||= date[/\d{4}/]
    end
    
    def valid_for_timeline?
      year.present?
    end
    
    def artist
      return nil unless fields['artist'].present?
      @artist ||= Artsy::Artist.new(fields['artist'], client)
    end
    
    def to_timeline
      {
        timeline: {
          headline: fields['display'],
          type: "default",
          text: description_html,
          asset: {
            media: image_version_url(default_image, 'large')
          },
          date: [self.to_timeline_date(classname: 'selected-item')] + related_artworks_with_dates.map(&:to_timeline_date),
          era: [artist.try(:to_timeline_era)].compact
        }
      }
    end
    
    def to_timeline_date(options = {})
      {
        startDate: [year].compact.join(","),
        endDate: [year].compact.join(","),
        headline: options[:headline].try(:call, self) || fields['display'],
        text: "<p>#{description}</p>",
        classname: options[:classname],
        asset: {
          media: large_image,
          thumbnail: thumbnail
        }
      }
    end
    
    private
    
    def related_artworks_with_dates
      @related_artworks_with_dates ||= related_artworks.select(&:valid_for_timeline?)
    end
    
    def related_artworks
      @related_artworks ||= client.find_related_artworks_for_artwork(id)
    end
  end
  
  class Gene < Artsy::Model
    def artworks_with_dates
      @artworks_with_dates ||= artworks.select(&:valid_for_timeline?)
    end
    
    def artists_with_dates
      @artists_with_dates ||= artists.select(&:valid_for_timeline_era?)
    end
    
    def valid_for_timeline?
      artworks_with_dates.any?
    end
    
    def to_timeline
      {
        timeline: {
          headline: name,
          type: "default",
          text: client.markdown.render(description),
          asset: {
            media: image_version_url(fields, 'square')
          },
          date: artworks_with_dates.map(&:to_timeline_date),
          era: artists_with_dates.map(&:to_timeline_era)
        }
      }
    end
    
    private
    
    def artworks
      @artworks ||= client.find_artworks_for_gene(id)
    end
    
    def artists
      @artists ||= client.find_artists_for_gene(id)
    end
  end
  
  class Tag < Artsy::Model
    def valid_for_timeline?
      artworks_with_dates.any?
    end
    
    def artworks_with_dates
      @artworks_with_dates ||= artworks.select(&:valid_for_timeline?)
    end
    
    def to_timeline
      {
        timeline: {
          headline: name,
          type: "default",
          asset: {
            media: image_version_url(fields, 'thumb', ignore_versions: true)
          },
          date: artworks_with_dates.map(&:to_timeline_date)
        }
      }
    end
    
    private
    
    def artworks
      @artworks ||= client.find_artworks_for_tag(id)
    end
  end
end
