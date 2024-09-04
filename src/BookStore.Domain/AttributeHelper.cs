using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FileStore.Domain
{
    public static class AttributeHelper
    {

        public static bool HasAttribute<T>(this Attribute attribute, T value)
            where T : System.Enum
        {
            var valuesWithAttribute = GetValuesWithAttribute<T>(attribute);

            return valuesWithAttribute.Any(x => EqualityComparer<T>.Default.Equals(x, value));
        }

        public static bool IsValueWithAttribute<T>(this Attribute attribute, T value)
        {
            var values = attribute.GetValuesWithAttribute<T>();

            return values.Contains(value);
        }

        public static IEnumerable<T> GetValuesWithAttribute<T>(this Attribute attribute)
        {
            var values = (T[])Enum.GetValues(typeof(T));

            var result = new List<T>();
            foreach (var value in (T[])Enum.GetValues(typeof(T)))
            {
                var memberInfos = typeof(T).GetMember(value.ToString());
                var enumValueMemberInfo = memberInfos.FirstOrDefault(m => m.DeclaringType == typeof(T));
                var valueAttributes = enumValueMemberInfo.GetCustomAttributes(attribute.GetType(), false);

                if (!valueAttributes.Any())
                    continue;

                result.Add(value);
            }

            return result;
        }
    }
}
