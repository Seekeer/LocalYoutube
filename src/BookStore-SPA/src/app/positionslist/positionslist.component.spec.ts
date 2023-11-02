import { ComponentFixture, TestBed } from '@angular/core/testing';

import { PositionslistComponent } from './positionslist.component';

describe('PositionslistComponent', () => {
  let component: PositionslistComponent;
  let fixture: ComponentFixture<PositionslistComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [ PositionslistComponent ]
    })
    .compileComponents();

    fixture = TestBed.createComponent(PositionslistComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
