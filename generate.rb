require 'countries'
require 'pry'
require 'active_support/all'
require 'erb'

ElmValue = Struct.new(:name, :type, keyword_init: true)
ElmFunction = Struct.new(:name, :args, :return_, :body, :docs, keyword_init: true) do
  def signature
    (args.map(&:type) + [return_.type]).join(' -> ')
  end

  def render
    <<~TEMPLATE
      {-|
        #{docs}
      -}
      #{name} : #{signature}
      #{name} #{args.map(&:name).join(' ')}=
          #{body}
    TEMPLATE
  end
end

def enumify(name:, members:)
  members = members.dup
  first = members.shift
  <<~TEMPLATE
    type #{name.camelize}
      = #{member_to_enum(first)}
      #{members.map { |member| "| #{member_to_enum(member)}" }.join("\n  ")}
  TEMPLATE
end

def member_to_enum(member)
  if member.blank?
    'None'
  else
    member.to_s.parameterize.underscore.camelize
  end
end

def escape_quotes(s)
  s.gsub('"', '\"')
end

def country_to_func_name(country)
  "country#{country.alpha2}"
end

continents = ISO3166::Country.all.map(&:continent).uniq.sort
regions = ISO3166::Country.all.map(&:region).uniq.sort
subregions = ISO3166::Country.all.map(&:subregion).uniq.sort
world_regions = ISO3166::Country.all.map(&:world_region).uniq.sort

country_funcs = ISO3166::Country.all.sort_by(&:name).map do |country|
  country = ISO3166::Country[country.alpha2]
  postal_code_format =
    if country.postal_code.blank?
      ''
    else
      country.postal_code_format.gsub('\\', '\\\\\\\\')
    end

  address_format =
    if country.address_format.blank?
      '""'
    else
      <<~TEMPLATE
        """#{country.address_format}
        """
      TEMPLATE
    end

  function_name = country_to_func_name(country)

  subdivision_function =
    if country.subdivisions?
      "#{function_name}Subdivisions"
    else
      '[]'
    end

  body = <<~TEMPLATE
    { addressFormat = #{address_format}
        , alpha2 = "#{country.alpha2}"
        , alpha3 = "#{country.alpha3}"
        , continent = Continent.#{member_to_enum(country.continent)}
        , countryCode = "#{country.country_code}"
        , currencyCode = "#{country.currency_code}"
        , emoji = "#{country.emoji_flag}"
        , gec = "#{country.gec}"
        , internationalPrefix = "#{country.international_prefix}"
        , ioc = "#{country.ioc}"
        , languagesOfficial = ["#{country.languages_official.join('", "')}"]
        , languagesSpoken = ["#{country.languages_spoken.join('", "')}"]
        , localNames = ["#{country.local_names.reject(&:blank?).join('", "')}"]
        , name = "#{country.name}"
        , nanpPrefix = "#{country.nanp_prefix}"
        , nationalDestinationCodeLengths = [#{country.national_destination_code_lengths.join(', ')}]
        , nationalNumberLengths = [#{country.national_number_lengths.join(', ')}]
        , nationalPrefix = "#{country.national_prefix}"
        , nationality = "#{country.nationality}"
        , number = "#{country.number}"
        , postalCode = #{country.postal_code.to_s.camelize}
        , postalCodeFormat = "#{postal_code_format}"
        , region = Region.#{member_to_enum(country.region)}
        , startOfWeek = Time.#{member_to_enum(country.start_of_week)[0..2]}
        , subdivisions = #{subdivision_function}
        , subregion = Subregion.#{member_to_enum(country.subregion)}
        , unLocode = "#{country.un_locode}"
        , unofficialNames = ["#{country.unofficial_names.join('", "')}"]
        , worldRegion = WorldRegion.#{member_to_enum(country.world_region)}
        }
  TEMPLATE

  docs = <<~TEMPLATE
    #{country.name}
  TEMPLATE

  ElmFunction.new(
    name: function_name,
    docs: docs,
    args: [],
    return_: ElmValue.new(name: 'country', type: 'Country'),
    body: body
  )
end

subdivision_funcs = ISO3166::Country.all.sort_by(&:alpha2).select(&:subdivisions?).map do |country|
  country = ISO3166::Country[country.alpha2]
  function_name = "#{country_to_func_name(country)}Subdivisions"

  subdivisions = country.subdivisions.map do |code, subdivision|
    next if subdivision.name.blank?

    <<~TEMPLATE
      { name = "#{subdivision.name}"
          , code = "#{code}"
          , unofficialNames = ["#{Array.wrap(subdivision.unofficial_names).join('", "')}"]}
    TEMPLATE
  end.compact

  body = "[ #{subdivisions.join('  , ')} ]"

  ElmFunction.new(
    name: function_name,
    args: [],
    return_: ElmValue.new(name: 'subdivisions', type: 'List Subdivision'),
    body: body,
    docs: ''
  )
end

continents_enum = enumify(name: 'Continent', members: continents)
regions_enum = enumify(name: 'Region', members: regions)
subregions_enum = enumify(name: 'Subregion', members: subregions)
world_regions_enum = enumify(name: 'WorldRegion', members: world_regions)

def continent_template
  ERB.new(<<~TEMPLATE)
    module ISO3166.Continent exposing (Continent(..))

    {-|
      @docs Continent
    -}

    {-|
      The continent of a country.
    -}
    <%= continents_enum %>
  TEMPLATE
end

def region_template
  ERB.new(<<~TEMPLATE)
    module ISO3166.Region exposing (Region(..))

    {-|
      @docs Region
    -}

    {-|
      The region of a country.
    -}
    <%= regions_enum %>
  TEMPLATE
end

def subregion_template
  ERB.new(<<~TEMPLATE)
    module ISO3166.Subregion exposing (Subregion(..))

    {-|
      @docs Subregion
    -}

    {-|
      The subregion of a country.
    -}
    <%= subregions_enum %>
  TEMPLATE
end

def world_region_template
  ERB.new(<<~TEMPLATE)
    module ISO3166.WorldRegion exposing (WorldRegion(..))

    {-|
      @docs WorldRegion
    -}

    {-|
      The world region of a country.
    -}
    <%= world_regions_enum %>
  TEMPLATE
end

def iso3166_template
  ERB.new(<<~TEMPLATE)
    module ISO3166 exposing (Country, Subdivision, all, findSubdivisionByCode, fromAlpha2, fromAlpha3, <%= (country_funcs + subdivision_funcs).map(&:name).join(', ') %>)

    {-|
      Based upon the country data from https://github.com/countries/countries
      Countries is a collection of all sorts of useful information for every country in the ISO 3166 standard. It contains info for the following standards ISO3166-1 (countries), ISO3166-2 (states/subdivisions), ISO4217 (currency) and E.164 (phone numbers). I will add any country based data I can get access to. I hope this to be a repository for all country based information.

      # Types

      @docs Country, Subdivision

      # Helpers

      @docs all, fromAlpha2, fromAlpha3, findSubdivisionByCode

      # Countries

      @docs <%= country_funcs.map(&:name).join(', ') %>

      # Subdivisions

      @docs <%= subdivision_funcs.map(&:name).join(', ') %>
    -}

    import Time
    import ISO3166.Continent as Continent exposing (Continent)
    import ISO3166.Region as Region exposing (Region)
    import ISO3166.Subregion as Subregion exposing (Subregion)
    import ISO3166.WorldRegion as WorldRegion exposing (WorldRegion)

    {-|
      Representation of a country.

      # Idenification Codes
          c.number # => "840"
          c.alpha2 # => "US"
          c.alpha3 # => "USA"
          c.gec    # => "US"
          c.un_locode # => "US"

      # Emoji
          c.emoji # => "🇺🇸"

      # Names and translations
          c.name # => "United States"
          c.unofficialNames # => ["United States of America", "Vereinigte Staaten von Amerika", "États-Unis", "Estados Unidos"]

          c = ISO3166.belgium
          c.localNames # => ["België", "Belgique", "Belgien"]

      # Subdivisions
          c.subdivisions

      # Location
          c.region # => "Americas"
          c.subregion # => "Northern America"

      # Telephone Routing
          c.countryCode # => "1"
          c.nationalDestinationCodeLengths # => [3]
          c.nationalNumberLengths # => [10]
          c.internationalPrefix # => "011"
          c.nationalPrefix # => "1"

      # Currency
          c.currencyCode # => "USD"

      # Address Formatting
      These templates are compatible with the Liquid template system.

          c.addressFormat # => "{{recipient}}\\n{{street}}\\n{{city}} {{region_short}} {{postalcode}}\\n{{country}}\\n"
    -}
    type alias Country =
        { addressFormat : String
        , alpha2 : String
        , alpha3 : String
        , continent : Continent
        , countryCode : String
        , currencyCode : String
        , emoji : String
        , gec : String
        , internationalPrefix : String
        , ioc : String
        , languagesOfficial : List String
        , languagesSpoken : List String
        , localNames : List String
        , name : String
        , nanpPrefix : String
        , nationalDestinationCodeLengths : List Int
        , nationalNumberLengths : List Int
        , nationalPrefix : String
        , nationality : String
        , number : String
        , postalCode : Bool
        , postalCodeFormat : String
        , region : Region
        , startOfWeek : Time.Weekday
        , subdivisions : List Subdivision
        , subregion : Subregion
        , unLocode : String
        , unofficialNames : List String
        , worldRegion : WorldRegion
        }

    {-|
      Representation of a subdivision.
    -}
    type alias Subdivision =
        { name : String
        , code : String
        , unofficialNames : List String
        }

    {-|
      A list of all countries.
    -}
    all : List Country
    all =
        [ <%= country_funcs.map(&:name).join(', ') %> ]


    {-|
      Find a country by it's alpha2 code.

          ISO3166.fromAlpha2 "US" # => Just { name = "United States", alpha2 = "US", alpha3 = "USA", ... }
    -}
    fromAlpha2 : String -> Maybe Country
    fromAlpha2 alpha2 =
      all
        |> List.filter (\\c -> c.alpha2 == alpha2)
        |> List.head

    {-|
      Find a country by it's alpha3 code.

          ISO3166.fromAlpha3 "US" # => Just { name = "United States", alpha3 = "US", alpha3 = "USA", ... }
    -}
    fromAlpha3 : String -> Maybe Country
    fromAlpha3 alpha3 =
      all
        |> List.filter (\\c -> c.alpha3 == alpha3)
        |> List.head

    {-|
      Find a subdivision by it's code.

          ISO3166.findSubdivisionByCode ISO3166.countryUS "NY" # => Just { name = "New York", code = "NY", ... }
    -}
    findSubdivisionByCode : Country -> String -> Maybe Subdivision
    findSubdivisionByCode country code =
      country.subdivisions
        |> List.filter (\\s -> s.code == code)
        |> List.head

    <%= country_funcs.map(&:render).join("\n\n") %>

    <%= subdivision_funcs.map(&:render).join("\n\n") %>
  TEMPLATE
end

File.write('src/ISO3166/Continent.elm', continent_template.result(binding))
File.write('src/ISO3166/Region.elm', region_template.result(binding))
File.write('src/ISO3166/Subregion.elm', subregion_template.result(binding))
File.write('src/ISO3166/WorldRegion.elm', world_region_template.result(binding))
File.write('src/ISO3166.elm', iso3166_template.result(binding))

`elm-format ./src --yes`
