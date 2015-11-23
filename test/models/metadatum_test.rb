require 'test_helper'

class MetadatumTest < ActiveSupport::TestCase
  setup do
    @metadatum1 = metadata(:metadatum1)
  end

  test 'bodyはbody_yamlをパースした結果を返す' do
    expect = YAML.load(@metadatum1.body_yaml)
    assert_equal expect, @metadatum1.body
  end

  test 'body=に与えた内容はシリアライズされてbody_yamlに格納される' do
    data = {'id' => 'foo', 'data' => {'foo' => 'bar'}}
    @metadatum1.body = data
    assert_equal data.to_yaml, @metadatum1.body_yaml
  end

  test 'bodyの構造があっていれば保存できる' do
    @metadatum = Metadatum.new(:body => @metadatum1.body)
    @metadatum.save
    assert @metadatum.valid?
  end

  test 'bodyの構造が不正なら保存できない' do
    @metadatum = Metadatum.new(:body => [{'foo' => 'bar'}])
    @metadatum.save
    assert !@metadatum.valid?
  end
end
