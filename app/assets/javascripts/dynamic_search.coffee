$(() ->
  $.widget('custom.dynamicSearch', {
    options: {}

    _create: () ->
      this.counter = this.element.find('.dynamic_search_active').size()
      if this.element.is('form')
        this.form = this.element
      else
        this.form = this.element.find('form')

      this.templates = this.form.prevAll('.templates:first').find('fieldset')
      if this.counter > 1
        this.element.find('.dynamic_search_remove').attr('style', null)

      that = this

      this.fieldsets().each( ->
        that.addTriggers($(this))
      )

      this.element.on('click', '.dynamic_search_add', (event) ->
        event.preventDefault
        newFieldset = that.addFieldset()
        that.addTriggers(newFieldset)
        return false
      )

      this.element.on('click', '.dynamic_search_clear', (event) ->
        event.preventDefault
        that.clear()
        return false
      )

    fieldsets: () ->
      this.form.find('fieldset')

    columnChange: (select) ->
      this.counter = this.counter + 1
      new_value = select.find('option:selected').attr('value')
      template = this.templates.filter('#dynamic_search_template_' + new_value)
      fieldset = select.closest('fieldset')
      input = fieldset.find('input[type=text]')

      fieldset.html(template.html().replace(/INDEX/g, this.counter))
      fieldset.attr('id', "dynamic_search_#{this.counter}")
      fieldset.find('.date').datepicker()
      fieldset.find('[class="' + input.attr('class') + '"]').val(input.val())

      if this.fieldsets().length > 1
        this.fieldsets().find('.dynamic_search_remove').attr('style', null)

      this.element.trigger('dynamicSearch:change')

      return fieldset

    addFieldset: () ->
      this.counter = this.counter + 1
      newFieldset = this.templates.filter('#dynamic_search_template_any_field').clone()
      if newFieldset.length == 0
        newFieldset = this.templates.filter('.dynamic_search_template:first').clone()

      newFieldset.attr('style', null)
      newFieldset.removeClass('dynamic_search_template')
      newFieldset.addClass('dynamic_search_active')
      newFieldset.html(newFieldset.html().replace(/INDEX/g, this.counter))
      newFieldset.attr('id', 'dynamic_search_' + this.counter)

      lastActive = this.element.find('.dynamic_search_active:last')
      if lastActive.length > 0
        lastActive.after(newFieldset)
      else
        this.element.find('.dynamic_search_fieldsets').prepend(newFieldset)

      this.fieldsets().find('.dynamic_search_remove').attr('style', null)
      this.element.trigger('dynamicSearch:add', { fieldset: newFieldset })

      return newFieldset

    remove: (fieldset) ->
      fieldset.remove()
      if this.fieldsets().length == 1
        this.fieldsets().find('.dynamic_search_remove').css('display', 'none')

      this.element.trigger('dynamicSearch:remove', { fieldset: fieldset })

    clear: () ->
      this.form.find('input[type=text]').each( ->
        $(this).val('')
      )
      this.form.submit()

    addTriggers: (fieldset) ->
      that = this
      fieldset.on('change', '.dynamic_search_column', (event) ->
        that.columnChange($(this))
      )
      fieldset.on('click', '.dynamic_search_remove', (event) ->
        that.remove(fieldset)
        event.preventDefault()
        return false
      )
    }
  )

)

$(->
  $('.dynamic_search').dynamicSearch()
)
