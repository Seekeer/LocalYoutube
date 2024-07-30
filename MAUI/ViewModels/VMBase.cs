using CommunityToolkit.Mvvm.ComponentModel;
using Dtos;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MAUI.ViewModels
{
    public partial class VMBase<T> : ObservableObject, IQueryAttributable
        where T : class
    {
        protected Action<T> _dtoAssign;

        public VMBase() { }

        public void ApplyQueryAttributes(IDictionary<string, object> query)
        {
            if (!query.Any() || !query.ContainsKey("dto") || _dtoAssign == null )
                return;
             
            var dto = query["dto"] as T;
            _dtoAssign(dto);
        }
    }
}
