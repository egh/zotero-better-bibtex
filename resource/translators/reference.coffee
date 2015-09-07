###
# Better BibTeX Reference Postscripting: Reference class
#
# The Bib(La)TeX references are generated by the `Reference` class. Before being comitted to the cache, you can add
# postscript code that can manipulated the `fields` or the `referencetype`
# 
# @param {Array} @fields Array of reference fields
# @param {String} @referencetype referencetype
# @param {Object} @item the current Zotero item being converted
#
# The fields are objects with the following keys:
#   * name: name of the Bib(La)TeX field
#   * value: the value of the field
#   * bibtex: the LaTeX-encoded value of the field
#   * enc: the encoding to use for the field
###
class Reference
  constructor: (@item) ->
    @fields = []
    @has = Object.create(null)
    @raw = ((tag.tag for tag in @item.tags when tag.tag == Translator.rawLaTag).length > 0)

    @referencetype = Translator.typeMap.Zotero2BibTeX[@item.itemType] || 'misc'

    @override = Translator.extractFields(@item)

    for own attr, f of Translator.fieldMap || {}
      @add(@clone(f, @item[attr])) if f.name

    @add({name: 'timestamp', value: Translator.testing_timestamp || @item.dateModified || @item.dateAdded})

  ###
  # Return a copy of the given `field` with a new value
  #
  # @param {field} field to be cloned
  # @param {value} value to be assigned
  # @return {Object} copy of field settings with new value
  ###
  clone: (f, value) ->
    clone = JSON.parse(JSON.stringify(f))
    delete clone.bibtex
    clone.value = value
    return clone

  ###
  # 'Encode' to raw LaTeX value
  #
  # @param {field} field to encode
  # @return {String} unmodified `field.value`
  ###
  enc_raw: (f) ->
    return f.value

  ###
  # Encode to LaTeX url
  #
  # @param {field} field to encode
  # @return {String} field.value encoded as verbatim LaTeX string (minimal escaping). If preference `fancyURLs` is on, wraps return value in `\href{string}{string}`
  ###
  enc_url: (f) ->
    value = @enc_verbatim(f)
    return "\\href{#{value}}{#{LaTeX.text2latex(value)}}" if Translator.fancyURLs
    return value

  ###
  # Encode to verbatim LaTeX
  #
  # @param {field} field to encode
  # @return {String} field.value encoded as verbatim LaTeX string (minimal escaping).
  ###
  enc_verbatim: (f) ->
    return @toVerbatim(f.value)

  nonLetters: new XRegExp("[^\\p{Letter}]", 'g')
  punctuationAtEnd: new XRegExp("[\\p{Punctuation}]$")
  postfixedParticle: (particle) ->
    return particle + ' ' if particle[particle.length - 1] == '.'
    return particle if XRegExp.test(particle, @punctuationAtEnd)
    return particle + ' '

  ###
  # Encode creators to author-style field
  #
  # @param {field} field to encode. The 'value' must be an array of Zotero-serialized `creator` objects.
  # @return {String} field.value encoded as author-style value
  ###
  enc_creators: (f, raw) ->
    return null if f.value.length == 0

    Translator.debug('enc_creators', f, 'raw:', raw)

    encoded = []
    for creator in f.value
      switch
        when creator.lastName && creator.fieldMode == 1
          name = if raw then "{#{creator.lastName}}" else @enc_latex({value: new String(creator.lastName)})

        when raw
          name = [creator.lastName || '', creator.firstName || ''].join(', ')

        when creator.lastName || creator.firstName
          name = {family: creator.lastName || '', given: creator.firstName || ''}
          # Parse name particles
          # Replicate citeproc-js logic for what should be parsed so we don't
          # break current behavior.
          fallback = false

          if name.family # && name.given
            # Don't parse if last name is quoted
            if name.family.length > 1 && name.family[0] == '"' && name.family[name.family.length - 1] == '"'
              name.family = @enc_latex({value: new String(name.family.slice(1, -1))})

            else
              Zotero.BetterBibTeX.CSL.parseParticles(name)

              source = XRegExp.replace((creator.firstName || '') + (creator.lastName || ''), @nonLetters, '')
              parsed = XRegExp.replace((part || '' for part in [name.given, name.family, name.suffix, name['non-dropping-particle'], name['dropping-particle']]).join(''), @nonLetters, '')
              fallback = (source.length != parsed.length)

              Translator.debug('particle parser: creator=', creator, "@#{source.length}=", source, 'name=', name, "@#{parsed.length}=", parsed, 'fallback:', fallback)

              if name['non-dropping-particle']
                name.family = @enc_latex({value: new String((@postfixedParticle(name['non-dropping-particle']) + name.family).trim())})
              else
                name.family = @enc_latex({value: name.family}).replace(/ and /g, ' {and} ')

              if name['dropping-particle']
                name.family = @postfixedParticle(@enc_latex({value: name['dropping-particle']}).replace(/ and /g, ' {and} ')) + name.family

          if name.given
            name.given = @enc_latex({value: name.given}).replace(/ and /g, ' {and} ')

          if name.suffix
            name = [name.family || '', name.suffix, name.given || '']
          else
            name = [name.family || '', name.given || '']
          # TODO: is this the best way to deal with commas?
          name = (part.replace(/,/g, '{,}') for part in name).join(', ')

          if fallback
            name = (part.replace(/,!/g, ',') for part in [creator.firstName + ' ' + creator.lastName] when part).join(' ')
            name = @enc_latex({value: name}).replace(/ and /g, ' {and} ').replace(/,/g, '{,}')

        else
          continue

      encoded.push(name.trim())

    return encoded.join(' and ')

  ###
  # Encode text to LaTeX
  #
  # This encoding supports simple HTML markup.
  #
  # @param {field} field to encode.
  # @return {String} field.value encoded as author-style value
  ###
  enc_latex: (f, raw) ->
    return f.value if typeof f.value == 'number'
    return null unless f.value

    if Array.isArray(f.value)
      return null if f.value.length == 0
      return (@enc_latex(@clone(f, word), raw) for word in f.value).join(f.sep)

    return f.value if raw

    value = LaTeX.text2latex(f.value)
    value = new String("{#{value}}") if f.value instanceof String
    return value

  enc_tags: (f) ->
    tags = (tag.tag for tag in f.value || [] when tag?.tag && tag.tag != Translator.rawLaTag)
    return null if tags.length == 0

    # sort tags for stable tests
    tags.sort() if Translator.testing

    tags = for tag in tags
      if Translator.BetterBibTeX
        tag = tag.replace(/([#\\%&])/g, '\\$1')
      else
        tag = tag.replace(/([#%\\])/g, '\\$1')

      # the , -> ; is unfortunate, but I see no other way
      tag = tag.replace(/,/g, ';')

      # verbatim fields require balanced braces -- please just don't use braces in your tags
      balanced = 0
      for ch in tag
        switch ch
          when '{' then balanced += 1
          when '}' then balanced -= 1
        break if balanced < 0
      tag = tag.replace(/{/g, '(').replace(/}/g, ')') if balanced != 0
      tag

    return tags.join(',')

  enc_attachments: (f) ->
    return null if not f.value || f.value.length == 0
    attachments = []
    errors = []

    for att in f.value
      a = {
        title: att.title
        path: att.localPath
        mimetype: att.mimeType || ''
      }

      save = Translator.exportFileData && att.defaultPath && att.saveFile
      a.path = att.defaultPath if save

      continue unless a.path # amazon/googlebooks etc links show up as atachments without a path

      a.title ||= att.path.replace(/.*[\\\/]/, '') || 'attachment'

      if a.path.match(/[{}]/) # latex really doesn't want you to do this.
        errors.push("BibTeX cannot handle file paths with braces: #{JSON.stringify(a.path)}")
        continue

      switch
        when save
          att.saveFile(a.path)
        when Translator.testing
          Translator.attachmentCounter += 1
          a.path = "files/#{Translator.attachmentCounter}/#{att.localPath.replace(/.*[\/\\]/, '')}"
        when Translator.exportPath && att.localPath.indexOf(Translator.exportPath) == 0
          a.path = att.localPath.slice(Translator.exportPath.length)

      attachments.push(a)

    f.errors = errors if errors.length != 0
    return null if attachments.length == 0

    # sort attachments for stable tests
    attachments.sort( ( (a, b) -> a.path.localeCompare(b.path) ) ) if Translator.testing

    return (att.path.replace(/([\\{};])/g, "\\$1") for att in attachments).join(';') if Translator.attachmentsNoMetadata
    return ((part.replace(/([\\{}:;])/g, "\\$1") for part in [att.title, att.path, att.mimetype]).join(':') for att in attachments).join(';')

  preserveCaps: {
    inner:  new XRegExp("(^|[\\s\\p{Punctuation}])([^\\s\\p{Punctuation}]+\\p{Uppercase_Letter}[^\\s\\p{Punctuation}]*)", 'g')
    all:    new XRegExp("(^|[\\s\\p{Punctuation}])([^\\s\\p{Punctuation}]*\\p{Uppercase_Letter}[^\\s\\p{Punctuation}]*)", 'g')
  }
  initialCapOnly: new XRegExp("^\\p{Uppercase_Letter}\\p{Lowercase_Letter}+$")

  isBibVar: (value) ->
    return value && Translator.preserveBibTeXVariables && value.match(/^[a-z][a-z0-9_]*$/i)

  ###
  # Add a field to the reference field set
  #
  # @param {field} field to add.
  ###
  add: (field) ->
    if ! field.bibtex
      return if typeof field.value != 'number' && not field.value
      return if typeof field.value == 'string' && field.value.trim() == ''
      return if Array.isArray(field.value) && field.value.length == 0

    @remove(field.name) if field.replace
    throw "duplicate field '#{field.name}' for #{@item.__citekey__}" if @has[field.name] && !field.allowDuplicates

    if ! field.bibtex
      if typeof field.value == 'number' || (field.preserveBibTeXVariables && @isBibVar(field.value))
        value = field.value
      else
        enc = field.enc || Translator.fieldEncoding?[field.name] || 'latex'
        value = @["enc_#{enc}"](field, (if field.enc && field.enc != 'creators' then false else @raw))

        return unless value

        unless field.bare && !field.value.match(/\s/)
          if Translator.preserveCaps != 'no' && field.preserveCaps && !@raw
            braced = []
            scan = value.replace(/\\./, '..')
            for i in [0...value.length]
              braced[i] = (braced[i - 1] || 0)
              braced[i] += switch scan[i]
                when '{' then 1
                when '}' then -1
                else          0
              braced[i] = 0 if braced[i] < 0

            value = XRegExp.replace(value, @preserveCaps[Translator.preserveCaps], (match, boundary, needle, pos, haystack) ->
              boundary ?= ''
              pos += boundary.length
              #return boundary + needle if needle.length < 2 # don't encode single-letter capitals
              return boundary + needle if pos == 0 && Translator.preserveCaps == 'all' && XRegExp.test(needle, Reference::initialCapOnly)

              c = 0
              for i in [pos - 1 .. 0] by -1
                if haystack[i] == '\\'
                  c++
                else
                  break
              return boundary + needle if c % 2 == 1 # don't enclose LaTeX command

              return boundary + needle if braced[pos] > 0
              return "#{boundary}{#{needle}}"
            )
          value = "{#{value}}"

      field.bibtex = "#{value}"

    field.bibtex = field.bibtex.normalize('NFKC') if @normalize
    @fields.push(field)
    @has[field.name] = field

  ###
  # Remove a field from the reference field set
  #
  # @param {name} field to remove.
  # @return {Object} the removed field, if present
  ###
  remove: (name) ->
    return unless @has[name]
    removed = @has[name]
    delete @has[name]
    @fields = (field for field in @fields when field.name != name)
    return removed

  normalize: (typeof (''.normalize) == 'function')

  CSLtoBibTeX: (variable) ->
    switch variable
      when 'original-date' then return 'origdate'
      when 'original-publisher' then return 'origpublisher'
      when 'original-publisher-place' then return 'origlocation'
      when 'original-title' then return 'origtitle'
      when 'authority' then return 'institution'
      when 'container-title'
        switch @referencetype
          when 'article', 'jurisdiction', 'legislation' then return 'journaltitle'

  postscript: ->

  complete: ->
    #@add({name: 'xref', value: @item.__xref__, enc: 'raw'}) if !@has.xref && @item.__xref__

    if Translator.DOIandURL != 'both'
      if @has.doi && @has.url
        switch Translator.DOIandURL
          when 'doi' then @remove('url')
          when 'url' then @remove('doi')

    fields = []
    for own name, value of @override
      raw = (value.format in ['naive', 'json'])
      name = name.toLowerCase()

      # psuedo-var, sets the reference type
      if name == 'referencetype'
        @referencetype = value.value
        continue

      Translator.debug('override:', name, value)

      switch value.format
        # CSL names are not in BibTeX format, so only add it if there's a mapping
        when 'csl'
          remapped = @CSLtoBibTeX(name)
          if remapped
            name = remapped
            Translator.debug('CSL override:', name, value)
          else
            Translator.debug('Unmapped CSL field', name, '=', value.value)
            continue

        when 'key-value'
          switch name
            when 'mr'
              fields.push({ name: 'mrnumber', value: value.value, raw: raw })
            when 'zbl'
              fields.push({ name: 'zmnumber', value: value.value, raw: raw })
            when 'lccn', 'pmcid'
              fields.push({ name: name, value: value.value, raw: raw })
            when 'pmid', 'arxiv', 'jstor', 'hdl'
              if Translator.BetterBibLaTeX
                fields.push({ name: 'eprinttype', value: name.toLowerCase() })
                fields.push({ name: 'eprint', value: value.value, raw: raw })
              else
                fields.push({ name, value: value.value, raw: raw })
            when 'googlebooksid'
              if Translator.BetterBibLaTeX
                fields.push({ name: 'eprinttype', value: 'googlebooks' })
                fields.push({ name: 'eprint', value: value.value, raw: raw })
              else
                fields.push({ name: 'googlebooks', value: value.value, raw: raw })
            when 'xref'
              fields.push({ name, value: value.value, enc: 'raw' })

            else
              fields.push({ name, value: value.value, raw: raw })
          continue

      fields.push({ name: name, value: value.value, raw: raw })

    for name in Translator.skipFields
      @remove(name)

    for field in fields
      name = field.name.split('.')
      if name.length > 1
        Translator.debug('override: per-reftype', name)
        continue unless @referencetype == name[0]
        field.name = name[1]

      Translator.debug('override: try', field)

      if (typeof field.value == 'string') && field.value.trim() == ''
        Translator.debug('override: scrub', field)
        @remove(field.name)
        continue

      Translator.debug('override: add', field)
      field = @clone(Translator.BibLaTeXDataFieldMap[field.name], field.value) if Translator.BibLaTeXDataFieldMap[field.name]
      field.replace = true
      @add(field)

    @add({name: 'type', value: @referencetype}) if @fields.length == 0

    try
      @postscript()
    catch err
      Translator.debug('postscript error:', err.message)

    # sort fields for stable tests
    @fields.sort((a, b) -> ("#{a.name} = #{a.value}").localeCompare(("#{b.name} = #{b.value}"))) if Translator.testing

    ref = "@#{@referencetype}{#{@item.__citekey__},\n"
    ref += ("  #{field.name} = #{field.bibtex}" for field in @fields).join(',\n')
    ref += '\n}\n\n'
    Zotero.write(ref)

    Zotero.BetterBibTeX.cache.store(@item.itemID, Translator, @item.__citekey__, ref) if Translator.caching

  toVerbatim: (text) ->
    if Translator.BetterBibTeX
      value = ('' + text).replace(/([#\\%&{}])/g, '\\$1')
    else
      value = ('' + text).replace(/([\\{}])/g, '\\$1')
    value = value.replace(/[^\x21-\x7E]/g, ((chr) -> '\\%' + ('00' + chr.charCodeAt(0).toString(16).slice(-2)))) if not Translator.unicode
    return value

  hasCreator: (type) -> (@item.creators || []).some((creator) -> creator.creatorType == type)
