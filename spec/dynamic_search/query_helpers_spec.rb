require 'spec_helper'

describe DynamicSearch::QueryHelpers do
  let(:klass) {
    class Test
      include DynamicSearch::QueryHelpers
    end.new
  }

  describe 'query_param_truthy?' do
    it 'is true when argument is "1"' do
      expect(klass.query_param_truthy?("1")).to be_truthy
    end

    it 'is true when argument is "true"' do
      expect(klass.query_param_truthy?("true")).to be_truthy
    end

    it 'is true when argument is true' do
      expect(klass.query_param_truthy?(true)).to be_truthy
    end
  end

  describe 'query_param_falsy?' do
    it 'inverts query_param_truythy? result' do
      allow(klass).to receive(:query_param_truthy?) { true }
      expect(klass.query_param_falsy?('value')).to be_falsey
    end
  end
end
