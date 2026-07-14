library SilentNullidity

define function Normalize(value Choice<Integer, String>):
  case
    when value is DateTime then ToString(value)
    when value is String then value as String
    else null
  end

define ChoiceResult:
  First(List<Choice<Boolean, String>> { true })

define SilentNullidity:
  Normalize(ChoiceResult)
