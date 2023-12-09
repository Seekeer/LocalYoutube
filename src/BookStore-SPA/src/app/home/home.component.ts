import {
  Component,
  OnInit,
} from '@angular/core';
import { ActivatedRoute } from '@angular/router';

@Component({
  selector: 'app-home',
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.css']
})
export class HomeComponent implements OnInit {

  public isMobile: boolean;
  public isActiveTab:number;
  
  constructor(
    private route: ActivatedRoute,
  ) {
   }


  ngOnInit(): void {
    
    this.isMobile =
      /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
        navigator.userAgent
      );
      
    const type = this.route.snapshot.queryParamMap.get('type');
    switch(type){
      case 'child':
        this.isActiveTab = 0;
        break;
      default:
        this.isActiveTab = 1;
        break;
    }


    (new MutationObserver(function (mutations, observer) {
      for (let i = 0; i < mutations.length; i++) {
          const m = mutations[i];
          if (m.type == 'childList') {
              for (let k = 0; k < m.addedNodes.length; k++) {
                  const autofocuses = (<Element>m.addedNodes[k]).querySelectorAll("[autofocus]"); //Note: this ignores the fragment's root element
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
