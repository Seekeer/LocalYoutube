import {
  Component,
  OnInit,
} from '@angular/core';

@Component({
  selector: 'app-home',
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.css']
})
export class HomeComponent implements OnInit {

  constructor() { }

  ngOnInit(): void {
    (new MutationObserver(function (mutations, observer) {
      for (let i = 0; i < mutations.length; i++) {
          const m = mutations[i];
          if (m.type == 'childList') {
              for (let k = 0; k < m.addedNodes.length; k++) {
                  const autofocuses = (<Element>m.addedNodes[k]).querySelectorAll("[autofocus]"); //Note: this ignores the fragment's root element
                  console.log(autofocuses);
                  if (autofocuses.length) {
                      const a = autofocuses[autofocuses.length - 1] ; // focus last autofocus element
                      (a as HTMLElement)?.focus();
                      (a as HTMLInputElement)?.select();
                  }
              }
          }
      }
  })).observe(document.body, { attributes: false, childList: true, subtree: true });
  
  }

}
