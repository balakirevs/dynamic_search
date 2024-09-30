require 'spec_helper'

describe DynamicSearch::Query do
  let(:config) {
    {
      integer: {type: :integer},
      string: {type: :string},
      enum: {type: :enum, values: ['type', 'another_type']},
      datetime: {type: :datetime},
      boolean: {type: :boolean},
      string_with_relation: {type: :string, relation: :parent_resource}
    }
  }

  let(:scope) {
    TestResource.all
  }

  let(:query) {
    DynamicSearch::Query.new(scope, {key: :integer, operator: :eq, value: 1}, config)
  }

  describe 'initialize' do
    it 'checks that query contains all required keys' do
      expect{
        DynamicSearch::Query.new(scope, {key: :integer, operator: :eq}, config)
      }.to raise_exception(DynamicSearch::Query::MissingRequiredKey)
    end
  end

  describe 'query_config' do
    it 'extracts relevant config with query_key' do
      expect(query.query_config).to eq({type: :integer})
    end
  end

  describe 'arel_query' do
    let(:arel_table) {
      scope.arel_table
    }

    it 'initializes new arel_table' do
      expect(query).to receive(:scope_klass) { scope }
      expect(arel_table).to receive('[]').with(:integer).and_call_original
      expect(scope).to receive(:arel_table) { arel_table }
      query.arel_query
    end

    context 'and query contains null: true and operator is negative' do
      it 'adds OR :attribute IS NULL' do
        query.query[:null] = true
        query.query[:operator] = :not_eq
        expr = query.arel_query.expr
        expect(expr.class).to eq(Arel::Nodes::Or)
        expect(expr.right.right.val).to eq(nil)
      end
    end

    context 'and query config contains null: true and operator is negative' do
      it 'adds OR :attribute IS NULL' do
        query.config[:integer][:null] = true
        query.query[:operator] = :not_eq
        expr = query.arel_query.expr
        expect(expr.class).to eq(Arel::Nodes::Or)
        expect(expr.right.right.val).to eq(nil)
      end
    end

    context 'when query contains null: true and operator is positive' do
      it 'does not add OR :attribute IS NULL' do
        query.query[:null] = true
        query.query[:operator] = :eq
        expect(query.arel_query.class).to eq(Arel::Nodes::Equality)
      end
    end
  end

  describe 'scope' do

    it 'uses arel_query' do
      expect(scope).to receive(:where).with(query.arel_query)
      query.scope
    end

    context 'when config[:scope] is true' do
      it 'calls key named method in scope' do
        query.config[:integer][:scope] = true
        expect(scope.klass).to receive(:integer).with(:eq, 1)
        query.scope
      end
    end

    context 'when config[:scope] is symbol or string' do
      it 'calls config[:scope] named method in scope' do
        query.config[:integer][:scope] = :some_scope
        expect(scope.klass).to receive(:some_scope).with(:eq, 1)
        query.scope
      end
    end

    context 'when value is nil' do
      it 'returns nil' do
        allow(query).to receive(:value) { nil }
        expect(query.scope).to be(nil)
      end
    end
  end

  describe 'operator' do
    it 'extracts operator from query' do
      query.query[:operator] = :eq
      expect(query.operator).to eq(:eq)
    end

    it 'raises exception if operator is not allowed' do
      query.query[:operator] = :invalid_operator
      expect{query.operator}.to raise_exception(DynamicSearch::Query::UnallowedOperator)
    end
  end

  describe 'attribute_name' do
    it 'extracts attribute_name from query config' do
      query.config[:integer][:attribute_name] = :integer_
      expect(query.attribute_name).to eq(:integer_)
    end

    it 'uses query key if if attribute_name is not present in config' do
      query.config[:integer][:attribute_name] = nil
      expect(query.attribute_name).to eq(:integer)
    end
  end

  describe 'value' do
    it 'returns nil when query[:value] is empty string' do
      query.query[:value] = ""
      expect(query.value).to be(nil)
    end

    it' returns nil when query[:value] is nil' do
      query.query[:value] = nil
      expect(query.value).to be(nil)
    end

    context 'when config[:value] is a proc' do
      before(:each) { query.config[:integer][:value] = ->(v) { v * 100 } }

      it 'value is passed to the proc' do
        expect(query.config[:integer][:value]).to receive(:call).with(1) { 1 }
        query.value
      end

      it 'proc return value is passed forward' do
        expect(query.value).to eq(100)
      end
    end

    context 'when type is :string' do
      before(:each) { query.query[:key] = :string }

      it 'is stringified' do
        query.query[:value] = 1
        expect(query.value).to eq("1")
      end
    end

    context 'when type is :integer' do
      before(:each) { query.query[:key] = :integer }

      it 'is numerified' do
        query.query[:value] = "1"
        expect(query.value).to eq(1)
      end
    end

    context 'when type is :enum' do
      before(:each) { query.query[:key] = :enum }

      context 'when value is in configured values' do
        it 'does nothing to the value' do
          query.query[:value] = 'type'
          expect(query.value).to eq(query.query[:value])
        end
      end

      context 'when value is not in configured values' do
        it 'raises exception' do
          query.query[:value] = 'invalid_type'
          expect{query.value}.to raise_exception(DynamicSearch::Query::InvalidValue)
        end
      end
    end

    context 'when type is :boolean' do
      before(:each) { query.query[:key] = :boolean }

      it 'is true for truthy values' do
        query.query[:value] = '1'
        expect(query.value).to eq(true)
        query.query[:value] = 'true'
        expect(query.value).to eq(true)
        query.query[:value] = true
        expect(query.value).to eq(true)
      end

      it 'is false for falsy values' do
        query.query[:value] = '0'
        expect(query.value).to eq(false)
        query.query[:value] = 'false'
        expect(query.value).to eq(false)
        query.query[:value] = false
        expect(query.value).to eq(false)
      end
    end

    context 'when type is :datetime' do
      before(:each) { query.query[:key] = :datetime }

      it 'parses value to DateTime' do
        query.query[:value] = '2014-01-01'
        expect(query.value).to eq(DateTime.parse('2014-01-01'))
      end
    end
  end

  describe 'type' do
    context 'when type is not supported' do
      it 'raises exception' do
        query.config[:integer][:type] = :some_type
        expect{query.type}.to raise_exception(DynamicSearch::Query::UnsupportedType)
      end
    end
  end

  describe 'scope_klass' do
    it 'is scope.klass' do
      expect(query.scope_klass).to eq(scope.klass)
    end

    context 'when config has relation' do
      it 'returns the relation class' do
        query.config[:integer][:relation] = {parent_resource: :parent_resource}
        expect(query.scope_klass).to eq(TestResource)
      end
    end
  end

  describe 'operator_for_arel' do
    before(:each) {
      query.query[:key] = :string
    }
    it 'returns operator' do
      query.query[:operator] = :eq
      expect(query.operator_for_arel).to eq(:eq)
    end

    context 'when operator is :begins_with' do
      it 'returns :matches' do
        query.query[:operator] = :begins_with
        expect(query.operator_for_arel).to eq(:matches)
      end
    end

    context 'when operator is :ends_with' do
      it 'returns :matches' do
        query.query[:operator] = :ends_with
        expect(query.operator_for_arel).to eq(:matches)
      end
    end
  end

  describe 'value_for_arel' do
    it 'returns value' do
      expect(query.value_for_arel).to eq(query.value)
    end

    context 'when type is :string' do
      before(:each) { query.query[:key] = :string }

      context 'and operator is :matches' do
        before(:each) { query.query[:operator] = :matches }

        it 'surrounds value with %' do
          expect(query.value_for_arel[0]).to eq('%')
          expect(query.value_for_arel[-1]).to eq('%')
        end
      end

      context 'and operator is :does_not_match' do
        before(:each) { query.query[:operator] = :does_not_match }

        it 'surrounds value with %' do
          expect(query.value_for_arel[0]).to eq('%')
          expect(query.value_for_arel[-1]).to eq('%')
        end
      end

      context 'and operator is :begins_with' do
        before(:each) { query.query[:operator] = :begins_with }

        it 'appends value with %' do
          expect(query.value_for_arel[-1]).to eq('%')
        end
      end

      context 'and operator is :ends_with' do
        before(:each) { query.query[:operator] = :ends_with }

        it 'prepends value with %' do
          expect(query.value_for_arel[0]).to eq('%')
        end
      end
    end

    context 'when type is :enum' do
      before(:each) { query.query[:key] = :enum }

      context 'and operator is an "in" operator' do
        before(:each) { query.query[:operator] = :in }

        it 'returns splitted value' do
          query.query[:value] = 'type,another_type'
          expect(query.value_for_arel).to eq(['type', 'another_type'])
        end
      end
    end
  end

  describe 'scope' do
    context 'when config has relation and operator is negative' do
      it 'does not joins relation with LEFT OUTER JOIN' do
        query = DynamicSearch::Query.new(scope, {key: :string_with_relation, operator: :not_eq, value: 'value'}, config)
        expect(query.scope.includes_values).not_to include(:parent_resource)
      end
    end

    context 'when config has relation and operator is positive' do
      it 'joins relation with INNER JOIN' do
        query = DynamicSearch::Query.new(scope, {key: :string_with_relation, operator: :eq, value: 'value'}, config)
        expect(query.scope.joins_values).to include(:parent_resource)
      end
    end
  end
end
