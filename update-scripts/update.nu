# to invoke generate_sources directly, enter nushell and run
# `use update.nu`
# `update generate_sources`

def get_latest_release [repo: string]: nothing -> string {
  try {
	http get $"https://api.github.com/repos/($repo)/releases"
#	  | where prerelease == false
#	  | where tag_name != "twilight"
          | get name
#	  | get tag_name
	  | get 0
  } catch { |err| $"Failed to fetch latest release, aborting: ($err.msg)" }
}

def get_updated_date [repo: string, tag: string] nothing -> string {
  try {
       http get $"https://api.github.com/repos/($repo)/releases" 
         | where tag_name == $tag 
         | get assets 
         | get 0 
         | where name == "zen.linux-x86_64.tar.xz" 
         | to json 
         | from json 
         | get updated_at
  } catch { |err| $"Failed to fetch updated date of ($tag), aborting ($err.msg)" }
}

def tag_newest [repo: string, tag: string] nothing -> string {
  let tag_updated_at = get_updated_date $repo $tag | into datetime | into int
  let twilight_updated_at = get_updated_date $repo "twilight" | into datetime | into int
  if $twilight_updated_at > $tag_updated_at { 
    return "twilight"
  }

  return $tag
}

def get_tag [repo: string]: nothing -> string {
  try {
        http get $"https://api.github.com/repos/($repo)/releases"
#         | where prerelease == false
#         | where tag_name != "twilight"
#          | get name
          | get tag_name
          | get 0
  } catch { |err| $"Failed to fetch latest release, aborting: ($err.msg)" }
}

def get_nix_hash [url: string]: nothing -> string  {
  nix store prefetch-file --hash-type sha256 --json $url | from json | get hash
}

export def generate_sources []: nothing -> record {
  let name = get_latest_release "zen-browser/desktop"
  let tag = get_tag "zen-browser/desktop" 
  let tag = tag_newest "zen-browser/desktop" $tag
  let updated_at = get_updated_date "zen-browser/desktop" $tag
  let prev_sources: record = open ./sources.json

  if $updated_at == $prev_sources.updated_at {
	# everything up to date
	return {
	  prev_tag: $tag
	  new_tag: $tag
	}
  }

  let x86_64_url = $"https://github.com/zen-browser/desktop/releases/download/($tag)/zen.linux-x86_64.tar.xz"
  let aarch64_url = $"https://github.com/zen-browser/desktop/releases/download/($tag)/zen.linux-aarch64.tar.xz"
  let sources = {
	name: $name
        version: $tag
	updated_at: $updated_at
	x86_64-linux: {
	  url:  $x86_64_url
	  hash: (get_nix_hash $x86_64_url)
	}
	aarch64-linux: {
	  url: $aarch64_url
	  hash: (get_nix_hash $aarch64_url)
	}
  }

  echo $sources | save --force "sources.json"

  return {
    new_tag: $tag
    prev_tag: $prev_sources.version
  }
}
