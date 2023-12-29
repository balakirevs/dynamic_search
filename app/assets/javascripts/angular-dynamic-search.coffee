#= require i18n
#= require i18n/translations

dynamicSearch = angular.module('dynamicSearch', [])

dynamicSearch.directive 'dynamicSearch', ['$parse', ($parse) ->
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

  defaultQuery = (config) ->
    inputKey = Object.keys(config)[0]
    inputOptions = config[inputKey]
    [
      {
        key: inputKey
        operator: (inputOptions.operators || OPERATORS[inputOptions.type])[0]
        value: ''
      }
    ]

  objectQueryToArray = (objectQuery = {}) ->
    arrayQuery = []
    Object.keys(objectQuery).forEach (key) ->
      arrayQuery[key] = objectQuery[key]
    arrayQuery

  arrayQueryToObject = (arrayQuery = []) ->
    objectQuery = {}
    arrayQuery.forEach (queryPart, index) ->
      objectQuery[index] = queryPart
    objectQuery

  translateKey = (key) ->
    I18n.t("dynamic_search.key.#{key}")

  translateAndSortKeys = (keys) ->
    _.chain(keys)
      .inject((memo, key) ->
        memo.push([key, translateKey(key)])
        memo
      , [])
      .sortBy((keyAndName) ->
        keyAndName[1]
      ).value()

  {
    controllerAs: 'dynamicSearch'
    controller: ['$scope', '$element', '$attrs', '$transclude', ($scope, $element, $attrs, $transclude) ->
      optionsAccessor = $parse($attrs.dynamicSearch)
      ctrl = this

      @options = optionsAccessor($scope) || {}
      @config = @options.config

      if queryVarName = @options.query
        $scope.$watch queryVarName, (newQuery) ->
          ctrl.query = objectQueryToArray(newQuery)

      @query ||= defaultQuery(@config)

      @keysForNgOptions = translateAndSortKeys(_.keys(@config))

      $scope.minDate = new Date()

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

      @addInput = ->
        ctrl.query.push defaultQuery(ctrl.config)[0]

      @removeInput = (input) ->
        ctrl.query.splice(ctrl.query.indexOf(input), 1)

      @submit = ->
        ctrl.options.submit(arrayQueryToObject(ctrl.query))

      @clearQuery = ->
        ctrl.query = defaultQuery(ctrl.config)

      @setInputDefaults = (queryPart) ->
        if (defaultValue = DEFAULT_VALUES[ctrl.typeFor(queryPart.key)])?
          queryPart.value = defaultValue

        inputOperators = ctrl.operatorsFor(queryPart.key)
        if inputOperators.indexOf(queryPart.operator) == -1
          queryPart.operator = inputOperators[0]

      @inputChanged = (type, value, queryPart) ->
        console.log(value)
        console.log(queryPart._value)
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

dynamicSearch.directive 'dynamicSearchFieldset', ->
  keySelectTemplate = '<select class="key form-control" ng-model="queryPart.key" ng-options="keyAndName[0] as keyAndName[1] for keyAndName in dynamicSearch.keysForNgOptions" ng-change="dynamicSearch.keyChanged(queryPart)"></select>'
  operatorSelectTemplate = '<select class="operator form-control" ng-model="queryPart.operator" ng-options="operator as dynamicSearch.translateOperator(operator) for operator in dynamicSearch.operatorsFor(queryPart.key)" ng-change="dynamicSearch.operatorChanged(queryPart)"></select>'
  stringInputTemplate = '<input class="value form-control type-string" type="text" ng-model="queryPart.value" ng-switch-when="string"></input>'
  integerInputTemplate = '<input class="value form-control type-integer" type="text" ng-model="queryPart.value" ng-switch-when="integer"></input>'
  enumSelectTemplate =
    '<div class="value type-enum" ng-switch-when="enum">' +
      '<ui-select multiple ng-if="dynamicSearch.useMultiselect(queryPart)" ng-model="queryPart.value">' +
      '<ui-select-match>{{$item ? dynamicSearch.translateValue(queryPart.key, $item, false) : $item}}</ui-select-match>' +
        '<ui-select-choices repeat="value in dynamicSearch.valuesFor(queryPart.key)">{{dynamicSearch.translateValue(queryPart.key, value, false)}}</ui-select-choices>' +
      '</ui-select>' +
      '<select class="form-control" ng-if="!dynamicSearch.useMultiselect(queryPart)" ng-model="queryPart.value" ng-options="value as dynamicSearch.translateValue(queryPart.key, value, false) for value in dynamicSearch.valuesFor(queryPart.key)"></select>' +
    '</div>'
  yearInputTemplate = '<input type="year" class="value form-control type-year" ng-model="queryPart.value" ng-switch-when="year" placeholder="YYYY"></input>'
  monthInputTemplate =
    '<div class="value type-month" ng-switch-when="month">' +
      '<input class="year form-control" type="number" min="0" max="9999" ng-model="queryPart._value[0]" placeholder="YYYY" ng-change="dynamicSearch.inputChanged(\'month\', _value, queryPart)"></input>' +
      '<select class="month form-control" ng-model="queryPart._value[1]" ng-change="dynamicSearch.inputChanged(\'month\', _value, queryPart)">' +
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
  booleanSelectTemplate = '<select class="value form-control type-boolean" ng-model="queryPart.value" ng-switch-when="boolean" ng-options="value as dynamicSearch.translateValue(queryPart.key, value) for value in [true, false]"></select>'
  fieldsetRemoveTemplate = '<a class="fieldset-remove" href="javascript:;" ng-click="dynamicSearch.removeInput(queryPart)" ng-show="dynamicSearch.query.length > 1">' + I18n.t('dynamic_search.remove_fieldset') + '</a>'
  {
    template: '<fieldset ng-repeat="queryPart in dynamicSearch.query" ng-switch="dynamicSearch.typeFor(queryPart.key)" class="ng-scope">' +
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
  }
