import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule } from '@angular/forms';
import { FormHandlerService } from '../form-handler.service';
import { BreadcrumbsManagerService } from '../breadcrumbs-manager.service';
import { MatSelectModule } from '@angular/material/select';
import { CourtHandlerService } from '../court-handler.service';

@Component({
	selector: 'app-contact-details',
	standalone: true,
	imports: [CommonModule, ReactiveFormsModule, MatSelectModule],
	templateUrl: './contact-details.component.html',
	styleUrl: './contact-details.component.scss'
})

export class ContactDetailsComponent implements OnInit 
{
	constructor(private breadcrumbsManagerService: BreadcrumbsManagerService,
				private formBuilder: FormBuilder,
				private router: Router,
				private formHandlerService: FormHandlerService,
				private courtHandlerService: CourtHandlerService) {}

	textAreaRemainingCharacters: string = "7000 תווים נותרו";

	selectedCourt: string | undefined = undefined;
	courtsList: any = [
		'בית משפט א',
		'בית משפט ב',
		'בית משפט ג',
		'בית משפט ד',
		'בית משפט ה',
		'בית משפט ו',
		'בית משפט ז',
		'בית משפט ח',
		'בית משפט ט',
	]

	form: any;
	currentPage = "step3";

	async ngOnInit() 
	{
		this.form = this.formBuilder.group({
			contactDescription: ['', Validators.required],
			courtCaseNumber: ['', Validators.pattern('[0-9]+')],
			courthouse: ['']
		});
		//this.form = this.formHandlerService.getStepValues('3');

		(await this.courtHandlerService.getCourtsList()).subscribe({
			next: (data: any) => {
				this.courtsList = data.courtsList;

				console.log(data);
			},
			error: (error: any) => {
				console.log(error);
			},
			complete: () => {
				
			}
		})

		this.updateFormGroup();

		const textArea = document.getElementById('contact-description-textarea') as HTMLTextAreaElement;
		const currentValue = textArea.value;

		const lengthRemaining = 7000 - currentValue.length;

		this.textAreaRemainingCharacters = `${lengthRemaining} תווים נותרו`;

		if(lengthRemaining < 0)
		{
			textArea.value = currentValue.substring(0, 7000);
			this.textAreaRemainingCharacters = `0 תווים נותרו`;
			this.textAreaRemainingCharacters = `0 תווים נותרו`;
			console.log("Zero tavim.");
		}

		
	}

	ngAfterViewInit(): void
	{
		this.breadcrumbsManagerService.setStep(3);
	}

	OnCourtSelectionChanged(event: any)
	{
		this.selectedCourt = event.value;

		this.form.patchValue({
			courthouse: this.selectedCourt
		});

		this.formHandlerService.updateStepFields('3', this.form);
	}

	GoToNextStep()
	{
		console.log(this.form.get('courthouse').value);
		this.formHandlerService.updateStepFields('3', this.form);
		//this.form = this.formHandlerService.getStepValues('3');

		if(!this.form.valid)
		{
			console.log(this.form.errors);

			Object.keys(this.form.controls).forEach(field => {
				const control = this.form.get(field);
				control?.markAsTouched({ onlySelf: true });
			});

			return;
		}

		this.router.navigate(['/step4']);
	}

	GoToPrevPage()
	{
		this.formHandlerService.updateStepFields('3', this.form);
		this.router.navigate(['/step2']);
	}

	updateFormGroup(): void 
	{
		var stepForm = this.formHandlerService.getStepValues('3');

		Object.keys(stepForm.controls).forEach((controlName) => {

			if(controlName === "courthouse")
			{
				this.selectedCourt = stepForm.get(controlName)?.value;
				this.form.patchValue({
					courthouse: this.selectedCourt
				});
			}

			else if(this.form.contains(controlName))
				this.form?.get(controlName)?.setValue(stepForm.get(controlName)?.value);
		});
	}

	OnTextAreaChanged(event: Event)
	{
		const textArea = event.target as HTMLTextAreaElement;
		const currentValue = textArea.value;

		const lengthRemaining = 7000 - currentValue.length;

		this.textAreaRemainingCharacters = `${lengthRemaining} תווים נותרו`;

		if(lengthRemaining < 0)
		{
			textArea.value = currentValue.substring(0, 7000);
			this.textAreaRemainingCharacters = `0 תווים נותרו`;
		}
	}
}
