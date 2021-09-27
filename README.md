# buildrtech/countries-elm

ISO3166 based repository for country data, generated from https://github.com/countries/countries.

It includes both countries, subdivisions and their ISO postal, currency and telecom information

Example usage:

```elm
c = ISO3166.countryUS
c.number # => "840"
c.alpha2 # => "US"
c.alpha3 # => "USA"
c.gec    # => "US"
c.un_locode # => "US"
```
