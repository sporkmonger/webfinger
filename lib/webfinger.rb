# Copyright 2010 Google, Inc.
# 
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
# 
#        http://www.apache.org/licenses/LICENSE-2.0
# 
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'webfinger/version'
require 'addressable/uri'
require 'addressable/template'
require 'xrd'
require 'openssl'

module WebFinger
  def self.normalize_acct_uri(acct_uri)
    acct_uri = Addressable::URI.parse(acct_uri).omit(:query, :fragment)
    acct_uri.scheme = 'acct'
    return acct_uri.normalize
  end

  def self.fetch_hostmeta(hostname)
    # TODO(sporkmonger) Fix this, quick and dirty right now.
    # TODO(sporkmonger) Implement simple LRDD caching.
    hostmeta_uri = Addressable::Template.new(
      'https://{hostname}/.well-known/host-meta'
    ).expand('hostname' => hostname)
    begin
      xrd = XRD.fetch_and_parse(hostmeta_uri)
    rescue OpenSSL::SSL::SSLError => e
      # Needs to handle 404 case
      warn(e)
      if hostmeta_uri.scheme == 'https'
        hostmeta_uri.scheme = 'http'
        retry
      else
        raise e
      end
    end
  end

  def self.lrdd_template(xrd)
    return Addressable::Template.new(xrd.links(:rel => 'lrdd')[0].template)
  end

  def self.lookup(email)
    email = self.normalize_acct_uri(email)
    # TODO(sporkmonger)
    # Lots of testing to make sure everything we do here to split out the
    # hostname is sane.
    hostname = email.path.split('@')[-1]
    hostmeta_xrd = self.fetch_hostmeta(hostname)
    template = self.lrdd_template(hostmeta_xrd)
    webfinger_uri = template.expand('uri' => email)
    return XRD.fetch_and_parse(webfinger_uri)
  end
end
