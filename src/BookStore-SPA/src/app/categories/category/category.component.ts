import {
  Component,
  OnInit,
} from '@angular/core';
import { NgForm } from '@angular/forms';
import {
  ActivatedRoute,
  Router,
} from '@angular/router';

import { ToastrService } from 'ngx-toastr';
import { Serie } from 'src/app/_models/Category';
import { SeriesService } from 'src/app/_services/series.service';

@Component({
  selector: 'app-category',
  templateUrl: './category.component.html',
  styleUrls: ['./category.component.css']
})
export class CategoryComponent implements OnInit {
  public formData: Serie;

  constructor(public service: SeriesService,
              private router: Router,
              private route: ActivatedRoute,
              private toastr: ToastrService) { }

  ngOnInit() {
    this.resetForm();

    let id;
    this.route.params.subscribe(params => {
      id = params['id'];
    });

    if (id != null) {
      this.service.getSerieById(id).subscribe(category => {
        this.formData = category;
      }, error => {
        this.toastr.error('An error occurred on get the record.');
      });
    } else {
      this.resetForm();
    }
  }

 private resetForm(form?: NgForm) {
    if (form != null) {
      form.form.reset();
    }

    // this.formData = {
    //   id: 0,
    //   name: ''
    // };
  }

  public onSubmit(form: NgForm) {
    if (form.value.id === 0) {
      this.insertRecord(form);
    } else {
      this.updateRecord(form);
    }
  }

  public insertRecord(form: NgForm) {
    this.service.addCategory(form.form.value).subscribe(() => {
      this.toastr.success('Registration successful');
      this.resetForm(form);
      this.router.navigate(['/categories']);
    }, () => {
      this.toastr.error('An error occurred on insert the record.');
    });
  }

  public updateRecord(form: NgForm) {
    this.service.updateCategory(form.form.value.id, form.form.value).subscribe(() => {
      this.toastr.success('Updated successful');
      this.resetForm(form);
      this.router.navigate(['/categories']);
    }, () => {
      this.toastr.error('An error occurred on update the record.');
    });
  }

  public cancel() {
    this.router.navigate(['/categories']);
  }
}
