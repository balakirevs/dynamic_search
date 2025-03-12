#= require i18n
#= require i18n/translations

multipleDynamicSearch = angular.module('multipleDynamicSearch', [])

multipleDynamicSearch.directive 'multipleDynamicSearch', ['$parse', ($parse) ->
  OPERATORS = {
    integer:  ['eq', 'not_eq', 'gteq', 'lteq'],
    string:   ['matches', 'does_not_match', 'begins_with', 'ends_with', 'eq', 'not_eq'],
    enum:     ['eq', 'not_eq', 'in', 'not_in'],
    year:     ['eq', 'gteq', 'lteq'],
    month:    ['eq', 'gteq', 'lteq'],
    date:     ['eq', 'gteq', 'lteq'],
    datetime: ['eq', 'gteq', 'lteq'],
    boolean:  ['eq', 'not_eq']
  }

  IN_OPERATORS = ['in', 'not_in']

  DEFAULT_VALUES = {
    boolean: true
    enum: undefined
  }

  sectionDefaultQuery = (section, sections) ->
    inputKey = Object.keys(sections[section])[0]
    inputOptions = sections[section][inputKey]
    [
      {
        key: inputKey
        operator: (inputOptions.operators || OPERATORS[inputOptions.type])[0]
        value: ''
      }
    ]

  defaultQuery = (sections) ->
    query = {}
    Object.keys(sections).forEach (section) ->
      query[section] = sectionDefaultQuery(section, sections)
    query

  objectQueryToQuerySections = (config, default_section, objectQuery = {}) ->
    querySections = {}
    angular.forEach objectQuery, (value, key) ->
      section = if config[value.key].section == undefined then default_section else config[objectQuery[key].key].section
      querySections[section] ||= []
      querySections[section].push(objectQuery[key])
    querySections

  querySectionsToObject = (querySections = []) ->
    objectQuery = {}
    index = 0
    Object.keys(querySections).forEach (key) ->
      querySections[key].forEach (queryPart) ->
        objectQuery[index++] = queryPart
    objectQuery

  translateKey = (key) ->
    I18n.t("dynamic_search.key.#{key}")

  translateAndSortKeys = (sections) ->
    translations = {}
    Object.keys(sections).forEach (section_name) ->
      translations[section_name] =
        _.chain(_.keys(sections[section_name]))
          .inject((memo, key) ->
            memo.push([key, translateKey(key)])
            memo
        , [])
          .sortBy((keyAndName) ->
            keyAndName[1]
        ).value()
    translations

  makeSections = (config, default_section) ->
    sections = {}
    if config
      Object.keys(config).forEach (key) ->
        section = config[key].section || default_section
        sections[section] ||= {}
        sections[section][key] = config[key]
    sections

  makeMapping = (sections) ->
    mapping = {}
    Object.keys(sections).forEach (section) ->
      mapping[section] = Object.keys(sections[section])
    mapping

  {
    controllerAs: 'multipleDynamicSearch'
    controller: ['$rootScope', '$scope', '$element', '$attrs', '$transclude', ($rootScope, $scope, $element, $attrs, $transclude) ->
      optionsAccessor = $parse($attrs.multipleDynamicSearch)
      ctrl = this

      @options = optionsAccessor($scope) || {}
      @config = @options.config
      @default_section = @options.default_section
      @sections = makeSections(@config, @default_section)
      @section_fields = makeMapping(@sections)

      if queryVarName = @options.query
        $scope.$watch queryVarName, (newQuery) ->
          ctrl.query = objectQueryToQuerySections(ctrl.config, ctrl.default_section, newQuery)

      @query ||= defaultQuery(@sections)

      @keysForNgOptions = translateAndSortKeys(@sections)

      $scope.minDate = new Date()

      @queryFor = (section) ->
        section_query = []
        ctrl.query.forEach (row) ->
          if ctrl.section_fields[section].includes(row.key)
            section_query.push(row)
        section_query

      @typeFor = (key) ->
        ctrl.config[key].type

      @operatorsFor = (key) ->
        ctrl.config[key].operators || OPERATORS[ctrl.typeFor(key)]

      @valuesFor = (key) ->
        ctrl.config[key].values

      @translateOperator = (operator) ->
        I18n.t("dynamic_search.operator.#{operator}")

      @translateValue = (key, value, returnError) ->
        return value if (returnError == false && I18n.t("dynamic_search.values.#{key}.#{value}").includes("[missing", "translation]"))
        I18n.t("dynamic_search.values.#{key}.#{value}")

      @addInput = (section) ->
        ctrl.query[section].push sectionDefaultQuery(section, ctrl.sections)[0]

      @removeInput = (input, section) ->
        if ctrl.query[section].length > 1
          ctrl.query[section].splice(ctrl.query[section].indexOf(input), 1)
        else
          $rootScope.$broadcast('removeLastFieldset', section)

      @submit = ->
        ctrl.options.submit(querySectionsToObject(ctrl.query))

      @clearQuery = ->
        ctrl.query = defaultQuery(ctrl.sections)

      @setInputDefaults = (queryPart) ->
        if (defaultValue = DEFAULT_VALUES[ctrl.typeFor(queryPart.key)])?
          queryPart.value = defaultValue

        inputOperators = ctrl.operatorsFor(queryPart.key)
        if inputOperators.indexOf(queryPart.operator) == -1
          queryPart.operator = inputOperators[0]

      @inputChanged = (type, value, queryPart) ->
        switch type
          when 'month'
            queryPart.value = "#{queryPart._value[0]}-#{queryPart._value[1]}"

      @useMultiselect = (queryPart) ->
        IN_OPERATORS.indexOf(queryPart.operator) >= 0

      @operatorChanged = (queryPart) ->
        type = ctrl.typeFor(queryPart.key)
        switch type
          when 'enum'
            if IN_OPERATORS.indexOf(queryPart.operator) >= 0
              queryPart.value = [queryPart.value] if typeof queryPart.value == 'string'
            else if typeof queryPart.value == 'object'
              queryPart.value = queryPart.value[0]

      @keyChanged = (queryPart) ->
        type = ctrl.typeFor(queryPart.key)
        switch type
          when 'enum'
            queryPart.value = undefined
        ctrl.setInputDefaults(queryPart)

      return this
    ]

    link: ($scope, $elem, $attrs) ->
  }
]

multipleDynamicSearch.directive 'multipleDynamicSearchFieldset', ['$parse', ($parse) ->
  keySelectTemplate = '<select class="key form-control" ng-model="queryPart.key" ng-options="keyAndName[0] as keyAndName[1] for keyAndName in multipleDynamicSearch.keysForNgOptions[section]" ng-change="multipleDynamicSearch.keyChanged(queryPart)"></select>'
  operatorSelectTemplate = '<select class="operator form-control" ng-model="queryPart.operator" ng-options="operator as multipleDynamicSearch.translateOperator(operator) for operator in multipleDynamicSearch.operatorsFor(queryPart.key)" ng-change="multipleDynamicSearch.operatorChanged(queryPart)"></select>'
  stringInputTemplate = '<input class="value form-control type-string" type="text" ng-model="queryPart.value" ng-switch-when="string"></input>'
  integerInputTemplate = '<input class="value form-control type-integer" type="text" ng-model="queryPart.value" ng-switch-when="integer"></input>'
  enumSelectTemplate =
    '<div class="value type-enum" ng-switch-when="enum">' +
      '<ui-select multiple ng-if="multipleDynamicSearch.useMultiselect(queryPart)" ng-model="queryPart.value">' +
      '<ui-select-match>{{$item ? multipleDynamicSearch.translateValue(queryPart.key, $item, false) : $item}}</ui-select-match>' +
      '<ui-select-choices repeat="value in multipleDynamicSearch.valuesFor(queryPart.key)">{{multipleDynamicSearch.translateValue(queryPart.key, value, false)}}</ui-select-choices>' +
      '</ui-select>' +
      '<select class="form-control" ng-if="!multipleDynamicSearch.useMultiselect(queryPart)" ng-model="queryPart.value" ng-options="value as multipleDynamicSearch.translateValue(queryPart.key, value, false) for value in multipleDynamicSearch.valuesFor(queryPart.key)"></select>' +
      '</div>'
  yearInputTemplate = '<input type="year" class="value form-control type-year" ng-model="queryPart.value" ng-switch-when="year" placeholder="YYYY"></input>'
  monthInputTemplate =
    '<div class="value type-month" ng-switch-when="month">' +
      '<input class="year form-control" type="number" min="0" max="9999" ng-model="queryPart._value[0]" placeholder="YYYY" ng-change="multipleDynamicSearch.inputChanged(\'month\', _value, queryPart)"></input>' +
      '<select class="month form-control" ng-model="queryPart._value[1]" ng-change="multipleDynamicSearch.inputChanged(\'month\', _value, queryPart)">' +
      '<option value="1">' + I18n.t('date.month_names.1') + '</value>' +
      '<option value="2">' + I18n.t('date.month_names.2') + '</value>' +
      '<option value="3">' + I18n.t('date.month_names.3') + '</value>' +
      '<option value="4">' + I18n.t('date.month_names.4') + '</value>' +
      '<option value="5">' + I18n.t('date.month_names.5') + '</value>' +
      '<option value="6">' + I18n.t('date.month_names.6') + '</value>' +
      '<option value="7">' + I18n.t('date.month_names.7') + '</value>' +
      '<option value="8">' + I18n.t('date.month_names.8') + '</value>' +
      '<option value="9">' + I18n.t('date.month_names.9') + '</value>' +
      '<option value="10">' + I18n.t('date.month_names.10') + '</value>' +
      '<option value="11">' + I18n.t('date.month_names.11') + '</value>' +
      '<option value="12">' + I18n.t('date.month_names.12') + '</value>' +
      '</select>' +
      '</div>'
  dateFutureInputTemplate = '<div class="value type-date-future" ng-switch-when="date_future"><date-input min="{{minDate | date:\'yyyy-MM-dd\'}}" ng-model="queryPart.value"></date-input></div>'
  dateInputTemplate = '<div class="value type-date" ng-switch-when="date"><date-input ng-model="queryPart.value"></date-input></div>'
  datetimeInputTemplate = '<div class="value type-datetime" ng-switch-when="datetime"><datetime-input ng-model="queryPart.value"></datetime-input></div>'
  booleanSelectTemplate = '<select class="value form-control type-boolean" ng-model="queryPart.value" ng-switch-when="boolean" ng-options="value as multipleDynamicSearch.translateValue(queryPart.key, value) for value in [true, false]"></select>'
  fieldsetRemoveTemplate = '<a class="fieldset-remove" href="javascript:;" ng-click="multipleDynamicSearch.removeInput(queryPart, section)" ng-show="multipleDynamicSearch.query[section].length > removeLength">' + I18n.t('dynamic_search.remove_fieldset') + '</a>'
  {
    template: '<legend ng-hide="hideTitle">{{ title }}</legend>' +
      '<fieldset ng-repeat="queryPart in multipleDynamicSearch.query[section]" ng-switch="multipleDynamicSearch.typeFor(queryPart.key)" class="ng-scope">' +
      keySelectTemplate +
      operatorSelectTemplate +
      stringInputTemplate +
      integerInputTemplate +
      enumSelectTemplate +
      yearInputTemplate +
      monthInputTemplate +
      dateFutureInputTemplate +
      dateInputTemplate +
      datetimeInputTemplate +
      #booleanSelectTemplate +
      fieldsetRemoveTemplate +
      '</fieldset>'
    scope: true
    link: ($scope, $elem, $attrs) ->
      $scope.section = $attrs.section
      $scope.hideTitle = $attrs.hideTitle
      $scope.title = I18n.t("dynamic_search.section_title.#{$scope.section}")
      $scope.removeLength = if $attrs.removeAllFieldsets then 0 else 1
  }
]
