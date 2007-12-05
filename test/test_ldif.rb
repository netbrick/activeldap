require 'al-test-utils'

class TestLDIF < Test::Unit::TestCase
  include ActiveLdap::GetTextSupport
  include AlTestUtils::Assertions
  include AlTestUtils::Config
  include AlTestUtils::ExampleFile

  priority :must
  def test_change_record_with_control
    ldif_source = <<-EOL
version: 1
# Delete an entry. The operation will attach the LDAPv3
# Tree Delete Control defined in [9]. The criticality
# field is "true" and the controlValue field is
# absent, as required by [9].
dn: ou=Product Development, dc=airius, dc=com
control: 1.2.840.113556.1.4.805 true
changetype: delete
EOL

    change_attributes = {
      "dn" => "ou=Product Development,dc=airius,dc=com",
    }

    ldif = assert_ldif(1, [change_attributes], ldif_source)
    record = ldif.records[0]
    assert_equal("delete", record.change_type)
    assert_true(record.delete?)
    assert_equal([{
                    :type => "1.2.840.113556.1.4.805",
                    :criticality => true,
                    :value => nil
                  }],
                 record.controls.collect {|control| control.to_hash})

    control = record.controls[0]
    assert_equal("1.2.840.113556.1.4.805", control.type)
    assert_true(control.criticality?)
    assert_nil(control.value)
  end

  def test_change_record_with_control_to_s
    ldif_source = <<-EOL
version: 1
# Delete an entry. The operation will attach the LDAPv3
# Tree Delete Control defined in [9]. The criticality
# field is "true" and the controlValue field is
# absent, as required by [9].
dn: ou=Product Development, dc=airius, dc=com
control: 1.2.840.113556.1.4.805 true
changetype: delete
EOL

    assert_ldif_to_s(<<-EOL, ldif_source)
version: 1
dn: ou=Product Development,dc=airius,dc=com
control: 1.2.840.113556.1.4.805 true
changetype: delete
EOL
  end

  def test_multi_change_type_records
    ldif_source = <<-EOL
version: 1
# Add a new entry
dn: cn=Fiona Jensen, ou=Marketing, dc=airius, dc=com
changetype: add
objectclass: top
objectclass: person
objectclass: organizationalPerson
cn: Fiona Jensen
sn: Jensen
uid: fiona
telephonenumber: +1 408 555 1212

# Delete an existing entry
dn: cn=Robert Jensen, ou=Marketing, dc=airius, dc=com
changetype: delete

# Modify an entry's relative distinguished name
dn: cn=Paul Jensen, ou=Product Development, dc=airius, dc=com
changetype: modrdn
newrdn: cn=Paula Jensen
deleteoldrdn: 1

# Rename an entry and move all of its children to a new location in
# the directory tree (only implemented by LDAPv3 servers).
dn: ou=PD Accountants, ou=Product Development, dc=airius, dc=com
changetype: modrdn
newrdn: ou=Product Development Accountants
deleteoldrdn: 0
newsuperior: ou=Accounting, dc=airius, dc=com

# Modify an entry: add an additional value to the postaladdress
# attribute, completely delete the description attribute, replace
# the telephonenumber attribute with two values, and delete a specific
# value from the facsimiletelephonenumber attribute
dn: cn=Paula Jensen, ou=Product Development, dc=airius, dc=com
changetype: modify
add: postaladdress
postaladdress: 123 Anystreet $ Sunnyvale, CA $ 94086
-
delete: description
-
replace: telephonenumber
telephonenumber: +1 408 555 1234
telephonenumber: +1 408 555 5678
-
delete: facsimiletelephonenumber
facsimiletelephonenumber: +1 408 555 9876
-

# Modify an entry: replace the postaladdress attribute with an empty
# set of values (which will cause the attribute to be removed), and
# delete the entire description attribute. Note that the first will
# always succeed, while the second will only succeed if at least
# one value for the description attribute is present.
dn: cn=Ingrid Jensen, ou=Product Support, dc=airius, dc=com
changetype: modify
replace: postaladdress
-
delete: description
-
EOL

    change_attributes_add = {
      "dn" => "cn=Fiona Jensen,ou=Marketing,dc=airius,dc=com",
      "objectclass" => ["top", "person", "organizationalPerson"],
      "cn" => ["Fiona Jensen"],
      "sn" => ["Jensen"],
      "uid" => ["fiona"],
      "telephonenumber" => ["+1 408 555 1212"],
    }

    change_attributes_delete = {
      "dn" => "cn=Robert Jensen,ou=Marketing,dc=airius,dc=com",
    }

    change_attributes_modrdn = {
      "dn" => "cn=Paul Jensen,ou=Product Development,dc=airius,dc=com",
    }

    change_attributes_modrdn_with_new_superior = {
      "dn" => "ou=PD Accountants,ou=Product Development,dc=airius,dc=com",
    }

    change_attributes_modify = {
      "dn" => "cn=Paula Jensen,ou=Product Development,dc=airius,dc=com",
    }

    change_attributes_modify_with_empty_replace = {
      "dn" => "cn=Ingrid Jensen,ou=Product Support,dc=airius,dc=com",
    }

    ldif = assert_ldif(1,
                       [change_attributes_add,
                        change_attributes_delete,
                        change_attributes_modrdn,
                        change_attributes_modrdn_with_new_superior,
                        change_attributes_modify,
                        change_attributes_modify_with_empty_replace],
                       ldif_source)
    record = ldif.records[0]
    assert_equal("add", record.change_type)
    assert_true(record.add?)

    record = ldif.records[1]
    assert_equal("delete", record.change_type)
    assert_true(record.delete?)

    record = ldif.records[2]
    assert_equal("modrdn", record.change_type)
    assert_true(record.modify_rdn?)
    assert_equal("cn=Paula Jensen", record.new_rdn)
    assert_true(record.delete_old_rdn?)
    assert_nil(record.new_superior)

    record = ldif.records[3]
    assert_equal("modrdn", record.change_type)
    assert_true(record.modify_rdn?)
    assert_equal("ou=Product Development Accountants", record.new_rdn)
    assert_false(record.delete_old_rdn?)
    assert_equal("ou=Accounting,dc=airius,dc=com", record.new_superior)

    record = ldif.records[4]
    assert_equal("modify", record.change_type)
    assert_true(record.modify?)
    operations = [
                  ["add", "postaladdress",
                   {"postaladdress" =>
                     ["123 Anystreet $ Sunnyvale, CA $ 94086"]}],
                  ["delete", "description", {}],
                  ["replace", "telephonenumber",
                   {"telephonenumber" => [
                                          "+1 408 555 1234",
                                          "+1 408 555 5678",
                                         ]}],
                  ["delete", "facsimiletelephonenumber",
                   {"facsimiletelephonenumber" => ["+1 408 555 9876"]}],
                 ]
    i = -1
    actual = record.operations.collect do |operation|
      i += 1
      type = operations[i][0]
      [operation.send("#{type}?"),
       [operation.type, operation.attribute, operation.attributes]]
    end
    assert_equal(operations.collect {|operation| [true, operation]},
                 actual)

    record = ldif.records[5]
    assert_equal("modify", record.change_type)
    assert_true(record.modify?)
    operations = [
                  ["replace", "postaladdress", {}],
                  ["delete", "description", {}],
                 ]
    i = -1
    actual = record.operations.collect do |operation|
      i += 1
      type = operations[i][0]
      [operation.send("#{type}?"),
       [operation.type, operation.attribute, operation.attributes]]
    end
    assert_equal(operations.collect {|operation| [true, operation]},
                 actual)
  end

  def test_modify_record
    ldif_source = <<-EOL
version: 1
# Modify an entry: add an additional value to the postaladdress
# attribute, completely delete the description attribute, replace
# the telephonenumber attribute with two values, and delete a specific
# value from the facsimiletelephonenumber attribute
dn: cn=Paula Jensen, ou=Product Development, dc=airius, dc=com
changetype: modify
add: postaladdress
postaladdress: 123 Anystreet $ Sunnyvale, CA $ 94086
-
delete: description
-
replace: telephonenumber
telephonenumber: +1 408 555 1234
telephonenumber: +1 408 555 5678
-
delete: facsimiletelephonenumber
facsimiletelephonenumber: +1 408 555 9876
-
EOL

    change_attributes = {
      "dn" => "cn=Paula Jensen,ou=Product Development,dc=airius,dc=com",
    }

    ldif = assert_ldif(1, [change_attributes], ldif_source)
    record = ldif.records[0]
    assert_equal("modify", record.change_type)
    assert_true(record.modify?)

    operations = [
                  ["add", "postaladdress",
                   {"postaladdress" =>
                     ["123 Anystreet $ Sunnyvale, CA $ 94086"]}],
                  ["delete", "description", {}],
                  ["replace", "telephonenumber",
                   {"telephonenumber" => [
                                          "+1 408 555 1234",
                                          "+1 408 555 5678",
                                         ]}],
                  ["delete", "facsimiletelephonenumber",
                   {"facsimiletelephonenumber" => ["+1 408 555 9876"]}],
                 ]
    i = -1
    actual = record.operations.collect do |operation|
      i += 1
      type = operations[i][0]
      [operation.send("#{type}?"),
       [operation.type, operation.attribute, operation.attributes]]
    end
    assert_equal(operations.collect {|operation| [true, operation]},
                 actual)
  end

  def test_modrdn_record_with_newsuperior
    ldif_source = <<-EOL
version: 1
# Rename an entry and move all of its children to a new location in
# the directory tree (only implemented by LDAPv3 servers).
dn: ou=PD Accountants, ou=Product Development, dc=airius, dc=com
changetype: modrdn
newrdn: ou=Product Development Accountants
deleteoldrdn: 0
newsuperior: ou=Accounting, dc=airius, dc=com
EOL

    change_attributes = {
      "dn" => "ou=PD Accountants,ou=Product Development,dc=airius,dc=com",
    }

    ldif = assert_ldif(1, [change_attributes], ldif_source)
    record = ldif.records[0]
    assert_equal("modrdn", record.change_type)
    assert_true(record.modify_rdn?)
    assert_equal("ou=Product Development Accountants", record.new_rdn)
    assert_false(record.delete_old_rdn?)
    assert_equal("ou=Accounting,dc=airius,dc=com", record.new_superior)
  end

  def test_modrdn_record
    ldif_source = <<-EOL
version: 1
# Modify an entry's relative distinguished name
dn: cn=Paul Jensen, ou=Product Development, dc=airius, dc=com
changetype: modrdn
newrdn: cn=Paula Jensen
deleteoldrdn: 1
EOL

    change_attributes = {
      "dn" => "cn=Paul Jensen,ou=Product Development,dc=airius,dc=com",
    }

    ldif = assert_ldif(1, [change_attributes], ldif_source)
    record = ldif.records[0]
    assert_equal("modrdn", record.change_type)
    assert_true(record.modify_rdn?)
    assert_equal("cn=Paula Jensen", record.new_rdn)
    assert_true(record.delete_old_rdn?)
    assert_nil(record.new_superior)
  end

  def test_delete_record
    ldif_source = <<-EOL
version: 1
# Delete an existing entry
dn: cn=Robert Jensen, ou=Marketing, dc=airius, dc=com
changetype: delete
EOL

    change_attributes = {
      "dn" => "cn=Robert Jensen,ou=Marketing,dc=airius,dc=com",
    }

    ldif = assert_ldif(1, [change_attributes], ldif_source)
    record = ldif.records[0]
    assert_equal("delete", record.change_type)
    assert_true(record.delete?)
  end

  def test_add_record
    ldif_source = <<-EOL
version: 1
# Add a new entry
dn: cn=Fiona Jensen, ou=Marketing, dc=airius, dc=com
changetype: add
objectclass: top
objectclass: person
objectclass: organizationalPerson
cn: Fiona Jensen
sn: Jensen
uid: fiona
telephonenumber: +1 408 555 1212
EOL

    change_attributes = {
      "dn" => "cn=Fiona Jensen,ou=Marketing,dc=airius,dc=com",
      "objectclass" => ["top", "person", "organizationalPerson"],
      "cn" => ["Fiona Jensen"],
      "sn" => ["Jensen"],
      "uid" => ["fiona"],
      "telephonenumber" => ["+1 408 555 1212"],
    }

    ldif = assert_ldif(1, [change_attributes], ldif_source)
    record = ldif.records[0]
    assert_equal("add", record.change_type)
    assert_true(record.add?)
  end

  def test_records_with_external_file_reference
    ldif_source = <<-EOL
version: 1
dn: cn=Horatio Jensen, ou=Product Testing, dc=airius, dc=com
objectclass: top
objectclass: person
objectclass: organizationalPerson
cn: Horatio Jensen
cn: Horatio N Jensen
sn: Jensen
uid: hjensen
telephonenumber: +1 408 555 1212
jpegphoto:< file://#{jpeg_photo_path}
EOL

    record = {
      "dn" => "cn=Horatio Jensen,ou=Product Testing,dc=airius,dc=com",
      "objectclass" => ["top", "person", "organizationalPerson"],
      "cn" => ["Horatio Jensen", "Horatio N Jensen"],
      "sn" => ["Jensen"],
      "uid" => ["hjensen"],
      "telephonenumber" => ["+1 408 555 1212"],
      "jpegphoto" => [jpeg_photo],
    }

    assert_ldif(1, [record], ldif_source)
  end

  def test_records_with_option_attributes
    ldif_source = <<-EOL
version: 1
dn:: b3U95Za25qWt6YOoLG89QWlyaXVz
# dn:: ou=<JapaneseOU>,o=Airius
objectclass: top
objectclass: organizationalUnit
ou:: 5Za25qWt6YOo
# ou:: <JapaneseOU>
ou;lang-ja:: 5Za25qWt6YOo
# ou;lang-ja:: <JapaneseOU>
ou;lang-ja;phonetic:: 44GI44GE44GO44KH44GG44G2
# ou;lang-ja:: <JapaneseOU_in_phonetic_representation>
ou;lang-en: Sales
description: Japanese office

dn:: dWlkPXJvZ2FzYXdhcmEsb3U95Za25qWt6YOoLG89QWlyaXVz
# dn:: uid=<uid>,ou=<JapaneseOU>,o=Airius
userpassword: {SHA}O3HSv1MusyL4kTjP+HKI5uxuNoM=
objectclass: top
objectclass: person
objectclass: organizationalPerson
objectclass: inetOrgPerson
uid: rogasawara
mail: rogasawara@airius.co.jp
givenname;lang-ja:: 44Ot44OJ44OL44O8
# givenname;lang-ja:: <JapaneseGivenname>
sn;lang-ja:: 5bCP56yg5Y6f
# sn;lang-ja:: <JapaneseSn>
cn;lang-ja:: 5bCP56yg5Y6fIOODreODieODi+ODvA==
# cn;lang-ja:: <JapaneseCn>
title;lang-ja:: 5Za25qWt6YOoIOmDqOmVtw==
# title;lang-ja:: <JapaneseTitle>
preferredlanguage: ja
givenname:: 44Ot44OJ44OL44O8
# givenname:: <JapaneseGivenname>
sn:: 5bCP56yg5Y6f
# sn:: <JapaneseSn>
cn:: 5bCP56yg5Y6fIOODreODieODi+ODvA==
# cn:: <JapaneseCn>
title:: 5Za25qWt6YOoIOmDqOmVtw==
# title:: <JapaneseTitle>
givenname;lang-ja;phonetic:: 44KN44Gp44Gr44O8
# givenname;lang-ja;phonetic::
  <JapaneseGivenname_in_phonetic_representation_kana>
sn;lang-ja;phonetic:: 44GK44GM44GV44KP44KJ
# sn;lang-ja;phonetic:: <JapaneseSn_in_phonetic_representation_kana>
cn;lang-ja;phonetic:: 44GK44GM44GV44KP44KJIOOCjeOBqeOBq+ODvA==
# cn;lang-ja;phonetic:: <JapaneseCn_in_phonetic_representation_kana>
title;lang-ja;phonetic:: 44GI44GE44GO44KH44GG44G2IOOBtuOBoeOCh+OBhg==
# title;lang-ja;phonetic::
# <JapaneseTitle_in_phonetic_representation_kana>
givenname;lang-en: Rodney
sn;lang-en: Ogasawara
cn;lang-en: Rodney Ogasawara
title;lang-en: Sales, Director
EOL

    record1 = {
      "dn" => "ou=営業部,o=Airius",
      "objectclass" => ["top", "organizationalUnit"],
      "ou" => [
               "営業部",
               {"lang-ja" =>
                 [
                  "営業部",
                  {"phonetic" => ["えいぎょうぶ"]},
                 ],
               },
               {"lang-en" => ["Sales"]},
              ],
      "description" => ["Japanese office"],
    }

    record2 = {
      "dn" => "uid=rogasawara,ou=営業部,o=Airius",
      "userpassword" => ["{SHA}O3HSv1MusyL4kTjP+HKI5uxuNoM="],
      "objectclass" => ["top", "person",
                        "organizationalPerson", "inetOrgPerson"],
      "uid" => ["rogasawara"],
      "mail" => ["rogasawara@airius.co.jp"],
      "givenname" => [
                      {"lang-ja" =>
                        [
                         "ロドニー",
                         {"phonetic" => ["ろどにー"]},
                        ]
                      },
                      "ロドニー",
                      {"lang-en" => ["Rodney"]},
                     ],
      "sn" => [
               {"lang-ja" =>
                 [
                  "小笠原",
                  {"phonetic" => ["おがさわら"]},
                 ]
               },
               "小笠原",
               {"lang-en" => ["Ogasawara"]},
              ],
      "cn" => [
               {"lang-ja" =>
                 [
                  "小笠原 ロドニー",
                  {"phonetic" => ["おがさわら ろどにー"]},
                 ],
               },
               "小笠原 ロドニー",
               {"lang-en" => ["Rodney Ogasawara"]},
              ],
      "title" => [
                  {"lang-ja" =>
                    [
                     "営業部 部長",
                     {"phonetic" => ["えいぎょうぶ ぶちょう"]}
                    ]
                  },
                  "営業部 部長",
                  {"lang-en" => ["Sales, Director"]},
                 ],
      "preferredlanguage" => ["ja"],
    }

    assert_ldif(1, [record1, record2], ldif_source)
  end

  def test_an_record_with_base64_encoded_value
    ldif_source = <<-EOL
version: 1
dn: cn=Gern Jensen, ou=Product Testing, dc=airius, dc=com
objectclass: top
objectclass: person
objectclass: organizationalPerson
cn: Gern Jensen
cn: Gern O Jensen
sn: Jensen
uid: gernj
telephonenumber: +1 408 555 1212
description:: V2hhdCBhIGNhcmVmdWwgcmVhZGVyIHlvdSBhcmUhICBUaGlzIHZhbHVl
 IGlzIGJhc2UtNjQtZW5jb2RlZCBiZWNhdXNlIGl0IGhhcyBhIGNvbnRyb2wgY2hhcmFjdG
 VyIGluIGl0IChhIENSKS4NICBCeSB0aGUgd2F5LCB5b3Ugc2hvdWxkIHJlYWxseSBnZXQg
 b3V0IG1vcmUu
EOL

    record = {
      "dn" => "cn=Gern Jensen,ou=Product Testing,dc=airius,dc=com",
      "objectclass" => ["top", "person", "organizationalPerson"],
      "cn" => ["Gern Jensen", "Gern O Jensen"],
      "sn" => ["Jensen"],
      "uid" => ["gernj"],
      "telephonenumber" => ["+1 408 555 1212"],
      "description" => ["What a careful reader you are!  " +
                        "This value is base-64-encoded because it has a " +
                        "control character in it (a CR).\r  By the way, " +
                        "you should really get out more."],
    }
    assert_ldif(1, [record], ldif_source)
  end

  def test_an_record_with_folded_attribute_value
    ldif_source = <<-EOL
version: 1
dn:cn=Barbara Jensen, ou=Product Development, dc=airius, dc=com
objectclass:top
objectclass:person
objectclass:organizationalPerson
cn:Barbara Jensen
cn:Barbara J Jensen
cn:Babs Jensen
sn:Jensen
uid:bjensen
telephonenumber:+1 408 555 1212
description:Babs is a big sailing fan, and travels extensively in sea
 rch of perfect sailing conditions.
title:Product Manager, Rod and Reel Division
EOL

    record = {
      "dn" => "cn=Barbara Jensen,ou=Product Development,dc=airius,dc=com",
      "objectclass" => ["top", "person", "organizationalPerson"],
      "cn" => ["Barbara Jensen", "Barbara J Jensen", "Babs Jensen"],
      "sn" => ["Jensen"],
      "uid" => ["bjensen"],
      "telephonenumber" => ["+1 408 555 1212"],
      "description" => ["Babs is a big sailing fan, and travels extensively " +
                        "in search of perfect sailing conditions."],
      "title" => ["Product Manager, Rod and Reel Division"],
    }
    assert_ldif(1, [record], ldif_source)
  end

  def test_records
    ldif_source = <<-EOL
version: 1
dn: cn=Barbara Jensen, ou=Product Development, dc=airius, dc=com
objectclass: top
objectclass: person
objectclass: organizationalPerson
cn: Barbara Jensen
cn: Barbara J Jensen
cn: Babs Jensen
sn: Jensen
uid: bjensen
telephonenumber: +1 408 555 1212
description: A big sailing fan.

dn: cn=Bjorn Jensen, ou=Accounting, dc=airius, dc=com
objectclass: top
objectclass: person
objectclass: organizationalPerson
cn: Bjorn Jensen
sn: Jensen
telephonenumber: +1 408 555 1212
EOL

    record1 = {
      "dn" => "cn=Barbara Jensen,ou=Product Development,dc=airius,dc=com",
      "objectclass" => ["top", "person", "organizationalPerson"],
      "cn" => ["Barbara Jensen", "Barbara J Jensen", "Babs Jensen"],
      "sn" => ["Jensen"],
      "uid" => ["bjensen"],
      "telephonenumber" => ["+1 408 555 1212"],
      "description" => ["A big sailing fan."],
    }
    record2 = {
      "dn" => "cn=Bjorn Jensen,ou=Accounting,dc=airius,dc=com",
      "objectclass" => ["top", "person", "organizationalPerson"],
      "cn" => ["Bjorn Jensen"],
      "sn" => ["Jensen"],
      "telephonenumber" => ["+1 408 555 1212"],
    }
    assert_ldif(1, [record1, record2], ldif_source)
  end

  def test_an_record
    ldif_source = <<-EOL
version: 1
dn: cn=Barbara Jensen, ou=Product Development, dc=airius, dc=com
objectclass: top
objectclass: person
objectclass: organizationalPerson
cn: Barbara Jensen
cn: Barbara J Jensen
cn: Babs Jensen
sn: Jensen
uid: bjensen
telephonenumber: +1 408 555 1212
description: A big sailing fan.
EOL

    record = {
      "dn" => "cn=Barbara Jensen,ou=Product Development,dc=airius,dc=com",
      "objectclass" => ["top", "person", "organizationalPerson"],
      "cn" => ["Barbara Jensen", "Barbara J Jensen", "Babs Jensen"],
      "sn" => ["Jensen"],
      "uid" => ["bjensen"],
      "telephonenumber" => ["+1 408 555 1212"],
      "description" => ["A big sailing fan."],
    }
    assert_ldif(1, [record], ldif_source)
  end

  def test_comment
    ldif_source = <<-EOL
version: 1
dn: cn=Barbara Jensen, ou=Product Development, dc=airius, dc=com
objectclass: top
# objectclass: person
#objectcl
 ass: organizationalPerson
EOL

    record = {
      "dn" => "cn=Barbara Jensen,ou=Product Development,dc=airius,dc=com",
      "objectclass" => ["top"],
    }
    assert_ldif(1, [record], ldif_source)
  end

  def test_dn_spec
    assert_invalid_ldif("'dn:' is missing",
                        "version: 1\n", 2, 1, "version: 1\n|@|")
    assert_invalid_ldif("DN is missing",
                        "version: 1\ndn:", 2, 4, "dn:|@|")
    assert_invalid_ldif("DN is missing",
                        "version: 1\ndn:\n", 3, 1, "dn:\n|@|")
    assert_invalid_ldif("DN is missing",
                        "version: 1\ndn: \n", 3, 1, "dn: \n|@|")

    dn = "cn=Barbara Jensen,ou=Product Development,dc=example,dc=com"
    cn = "Barbara Jensen"
    assert_valid_dn(dn,
                    "version: 1\ndn: #{dn}\ncn:#{cn}\n")

    encoded_dn = Base64.encode64(dn).gsub(/\n/, "\n ")
    encoded_cn = Base64.encode64(cn).gsub(/\n/, "\n ")
    assert_valid_dn(dn, "version: 1\ndn:: #{encoded_dn}\ncn::#{encoded_cn}\n")
  end

  def test_version_number
    assert_valid_version(1, "version: 1\ndn: dc=com\ndc: com")
    assert_valid_version(1, "version: 1\r\ndn: dc=com\ndc: com\n")
    assert_valid_version(1, "version: 1\r\n\n\r\n\ndn: dc=com\ndc: com\n")

    assert_invalid_ldif("unsupported version: 0",
                        "version: 0", 1, 11, "version: 0|@|")
    assert_invalid_ldif("unsupported version: 2",
                        "version: 2", 1, 11, "version: 2|@|")
  end

  def test_version_spec
    assert_invalid_ldif("version spec is missing",
                        "", 1, 1, "|@|")
    assert_invalid_ldif("version spec is missing",
                        "VERSION: 1", 1, 1, "|@|VERSION: 1")
    assert_invalid_ldif("version number is missing",
                        "version:", 1, 9, "version:|@|")
    assert_invalid_ldif("version number is missing",
                        "version: ", 1, 10, "version: |@|")
    assert_invalid_ldif("version number is missing",
                        "version: XXX", 1, 10, "version: |@|XXX")
  end

  priority :normal

  private
  def assert_ldif(version, records, ldif_source)
    ldif = ActiveLdap::Ldif.parse(ldif_source)
    assert_equal(version, ldif.version)
    assert_equal(records,
                 ldif.records.collect {|record| record.to_hash})
    ldif
  end

  def assert_valid_dn(dn, ldif_source)
    ldif = ActiveLdap::Ldif.parse(ldif_source)
    assert_equal([dn], ldif.records.collect {|record| record.dn})
  end

  def assert_valid_version(version, ldif_source)
    ldif = ActiveLdap::Ldif.parse(ldif_source)
    assert_equal(version, ldif.version)
  end

  def assert_invalid_ldif(reason, ldif, line, column, nearest)
    exception = assert_raise(ActiveLdap::LdifInvalid) do
      ActiveLdap::Ldif.parse(ldif)
    end
    assert_equal([_(reason), line, column, nearest, ldif],
                 [exception.reason, exception.line, exception.column,
                  exception.nearest, exception.ldif])
  end

  def assert_ldif_to_s(expected_ldif_source, original_ldif_source)
    ldif = ActiveLdap::Ldif.parse(original_ldif_source)
    assert_equal(expected_ldif_source, ldif.to_s)
  end
end